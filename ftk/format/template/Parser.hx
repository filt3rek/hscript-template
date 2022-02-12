package ftk.format.template;

using StringTools;

/**
 * @version 1.2.3
 * @author filt3rek
 */

enum ETemplateToken{
	EText( s : String );
	EExpr( s : String );
	EDo( s : String );
	EIf( s : String );
	EElseIf( s : String );
	EElse;
	EBreak;
	EFor( s : String );
	EWhile( s : String );
	ESwitch( s : String );
	ECase( s : String );
	EEnd;
}

class Parser{
	public var SIGN		= ":";
	public var COMMENT	= "*";
	public var IF		= "if";
	public var ELSE		= "else";
	public var ELSEIF	= "elseif";
	public var FOR		= "for";
	public var WHILE	= "while";
	public var BREAK	= "break";
	public var SWITCH	= "switch";
	public var CASE		= "case";
	public var END		= "end";
	public var DO		= "do";

	var source		: String;
	var comments	: String;
	var out			: String;
	var len			: Int;
	var pos			: Int;

	public function new(){}

	/*  
	*	Main function that parse a template's source into hscript source
	*	
	*	@param	str	: Template's source
	*/

	public function parse( str : String ){
		source		= str;
		var flow	= [];
		
		pos		= 0;
		len		= source.length;
		
		var isInsideExpr	= false;
		var doWriteText		= true;
#if ( !macro || ( macro && hscript_template_macro_pos ) )
		var switchTextFlow	= [];
#end
		while( true ){
			var t	= token( isInsideExpr );
			switch t {
				case null		: break;
				case EText(_)	:
					isInsideExpr	= true;
				case ESwitch(_)	:
					flow.push( t );
					doWriteText		= false;
					isInsideExpr	= false;
					continue;
				case ECase(_)	:
					flow.push( t );
#if ( !macro || ( macro && hscript_template_macro_pos ) )
					flow			= flow.concat( switchTextFlow );
					switchTextFlow	= [];
#end
					doWriteText		= true;
					isInsideExpr	= false;
					continue;
				case _			:
					isInsideExpr	= false;
			}
			if( doWriteText ){
				flow.push( t );
			}
#if ( !macro || ( macro && hscript_template_macro_pos ) )
			else{
				switchTextFlow.push( t );
			}
#end
		}

		var isInComment	= false;
#if ( !macro || ( macro && hscript_template_macro_pos ) )
		comments	= "";
#end
#if macro
		out	= '{var __s__="";';
#else
		out	= '{__s__="";';
#end
		for( token in flow ){
			switch token {
				case EText( s ) :
					if( isInComment ){
						addComment( s, true );
					}else{
						s	= s.split( '"' ).join( '\\"' );
						out	+= '__s__+="$s";';
					}
				case EExpr( s ) : 
					if( s.startsWith( COMMENT ) && s.endsWith( COMMENT ) ){
#if ( !macro || ( macro && hscript_template_macro_pos ) )
						out	+= 'var __comment__ = "' + ( SIGN + SIGN + s + SIGN + SIGN ).split( '"' ).join( '\\"' ) + '";';
#end
					}else if( s.startsWith( COMMENT ) ){
						isInComment	= true;
						addComment( s );
					}else if( s.endsWith( COMMENT ) ){
						addComment( s );
#if ( !macro || ( macro && hscript_template_macro_pos ) )
						comments	= comments.split( '"' ).join( '\\"' );
						out	+= 'var __comment__ = "' + comments + '";';
						comments	= "";
#end
						isInComment	= false;
					}else{
						if( isInComment ){
							addComment( s );
						}else{
#if macro
							out	+= '__s__+=$s;';
#else
							out	+= '__s__+=__toString__( $s );';
#end
						}
					}
				case EIf( s ) 	: 
					if( isInComment ){
						addComment( IF + s );
					}else{
						out	+= 'if($s){';
					}
				case EElseIf( s ) 	: 
					if( isInComment ){
						addComment( ELSEIF + s );
					}else{
						out	+= '}else if($s){';
					}
				case EFor( s ) 	: 
					if( isInComment ){
						addComment( FOR + s );
					}else{
						out	+= 'for$s{';
					}
				case EWhile( s ) 	: 
					if( isInComment ){
						addComment( WHILE + s );
					}else{
						out	+= 'while($s){';
					}
				case EDo( s ) 	: 
					if( isInComment ){
						addComment( DO + s );
					}else{
						out	+= '$s;';
					}
				case EElse		: 
					if( isInComment ){
						addComment( ELSE );
					}else{
						out	+= '}else{';
					}
				case EBreak		: 
					if( isInComment ){
						addComment( BREAK );
					}else{
						out	+= 'break;';
					}
				case ESwitch( s )	:
					if( isInComment ){
						addComment( SWITCH + s );
					}else{
						out	+= 'switch($s){';
					}
				case ECase( s )		: 
					if( isInComment ){
						addComment( CASE + s );
					}else{
						out	+= 'case$s:';
					}
				case EEnd		 : 
					if( isInComment ){
						addComment( END );
					}else{
						out	+= '}';
					}
			}
		}
		out	+= "return __s__;}";
		return out;
	}

	inline function addComment( s : String, isText = false ){
#if ( !macro || ( macro && hscript_template_macro_pos ) )
		if( isText ){
			comments	+= s;
		}else{
			comments	+= SIGN + SIGN + s + SIGN + SIGN;
		}
#end
	}

	function token( isInsideExpr : Bool ){
		if( pos >= len ) return null;
		
		var start	= pos;
		if( isInsideExpr ){
			seekSpecial();
			var sub	= source.substr( start, pos - start );
			start	= pos;
			seekSign();
			if( sub == IF ){
				sub	= source.substr( start, pos - start - 2 );
				return EIf( sub );
			}else if( sub == ELSEIF ){
				sub	= source.substr( start, pos - start - 2 );
				return EElseIf( sub );
			}else if( sub == FOR ){
				sub	= source.substr( start, pos - start - 2 );
				return EFor( sub );
			}else if( sub == WHILE ){
				sub	= source.substr( start, pos - start - 2 );
				return EWhile( sub );
			}else if( sub == SWITCH ){
				sub	= source.substr( start, pos - start - 2 );
				return ESwitch( sub );
			}else if( sub == CASE ){
				sub	= source.substr( start, pos - start - 2 );
				return ECase( sub );
			}else if( sub == DO ){
				sub	= source.substr( start, pos - start - 2 );
				return EDo( sub );
			}else if( sub == ELSE ){
				return EElse;
			}else if( sub == BREAK ){
				return EBreak;
			}else if( sub == END ){
				return EEnd;
			}else{
				sub	+= source.substr( start, pos - start - 2 );
				return EExpr( sub );
			}			
		}else{
			var sub	= if( !seekSign() ){
				source.substr( start, pos - start - 2 );
			}else{
				source.substr( start, pos - start );
			}
			return EText( sub );
		}
	}

	inline function seekSign(){
		var isEOF = true;
		while( pos < len ){
			var c	= source.charAt( pos++ );
			if( c == SIGN ){
				c	= source.charAt( pos++ );
				if( c == SIGN )	{
					isEOF	= false;
					break;
				}
			}
		}
		return isEOF;
	}

	inline function seekSpecial(){
		while( pos < len ){
			if( isSpecial( source.charAt( pos ) ) )	break;
			pos++;
		}
	}

	inline function isSpecial( c : String ){
		return c == " " || c == "\t" || c == "\r" || c == "\n" || c == "(" || c == SIGN;
	}
}