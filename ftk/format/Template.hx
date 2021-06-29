package ftk.format;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Compiler;
import haxe.macro.ExprTools;
import haxe.macro.MacroStringTools;
#end

using StringTools;
#if macro
using haxe.macro.ExprTools;
#end

/**
 * ...
 * @author filt3rek
 */

#if ( hscript && hscriptPos )
class TemplateError {
	public var line		(default,null)	: Int;
	public var message	(default,null)	: String;
	public var native	(default,null)	: hscript.Expr.Error;

	public function new( e : hscript.Expr.Error, message : String ){
		this.native		= e;
		this.line		= e.line;
		this.message	= message;
	}

	public function toString(){
		return 'Line $line : $message';
	}
}
#end

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
 
class Template {

#if macro
	static var stringInterpolationToken	= "$";
	static var templateMeta				= "template";
#end

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

	public var flow	: Array<ETemplateToken>;
	public var out	: String;		
	
	var source		: String;
#if hscriptPos
	var comments	: String;
#end
	var len			: Int;
	var pos			: Int;

	public function new() {}

	public function parse( str : String ){
		source	= str;
		flow	= [];
		
		pos		= 0;
		len		= source.length;
		
		var isInsideExpr	= false;
		var doWriteText		= true;
#if hscriptPos
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
#if hscriptPos
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
#if hscriptPos
			else{
				switchTextFlow.push( t );
			}
#end
		}

		var isInComment	= false;
#if hscriptPos
		comments	= "";
#end
		out	= 'var __s__="";';
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
#if hscriptPos
						out	+= 'var __comment__ = "' + ( SIGN + SIGN + s + SIGN + SIGN ).split( '"' ).join( '\\"' ) + '";';
#end
					}else if( s.startsWith( COMMENT ) ){
						isInComment	= true;
						addComment( s );
					}else if( s.endsWith( COMMENT ) ){
						addComment( s );
#if hscriptPos
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
							out	+= '__s__+=toString( $s );';
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
		out	+= "return __s__;";
		return out;
	}

	inline function addComment( s : String, isText = false ){
#if hscriptPos
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

#if hscript
	public function execute( ctx : {} ){
		try{
			var parser	= new hscript.Parser();
			var ast 	= parser.parseString( out );
			var interp 	= new hscript.Interp();
			for( field in Reflect.fields( ctx ) ){
				interp.variables.set( field, Reflect.field( ctx, field ) );
			}
			interp.variables.set( "toString", Std.string );
			var ret		: String =  interp.execute( ast );
			return ret;
		}
#if hscriptPos
		catch( e : hscript.Expr.Error ){
			var lines	= source.split( "\n" );
			throw new TemplateError( e, hscript.Printer.errorToString( e ) + " : " + lines[ e.line - 1 ].trim() );
		}
#end
	}
#end

	//	Compile-time templates
	
	/*  Manual build function
	*	Usage : public function myFunction( arg1, arg2... ){
	*		var x = "foo";
	*		...
	*		ftk.format.Template.buildFromFile( "my/path/to/templateFile" );
	*	}
	*
	*	Add `-D hscriptPos` to report error line related to hscript interpreter/macro exprs generator (synthax errors)
	*	Add `-D templatePos` to report error line related to generated expressions
	*/

#if hscript
	macro public static function buildFromFile( path : String, ?epath : ExprOf<String>, ?estringInterpolationToken : ExprOf<String>, ?eisFullPath : ExprOf<Bool> ) {
#if display
		return;
#end
		var path						: String	= evalConstExpr( epath );
		var stringInterpolationToken	: String	= evalConstExpr( estringInterpolationToken );
		var isFullPath					: Bool		= evalConstExpr( eisFullPath );

		var pos		= Context.currentPos();

		if( path != null && !isFullPath ){
			path	= getFullPath( path );
		}

		var content = try{
			sys.io.File.getContent( path );
		}catch( e ){
			Context.fatalError( e.message, pos );
		}

		pos	= Context.makePosition( { file : path, min : 0, max : 0 } );
		
		return macro @:pos( pos ) ftk.format.Template.buildFromString( $v{ content }, $v{ path }, $v{ stringInterpolationToken }, true );
	}

	macro public static function buildFromString( econtent : ExprOf<String>, ?epath : ExprOf<String>, ?estringInterpolationToken : ExprOf<String>, ?eisFullPath : ExprOf<Bool> ){
#if display
		return;
#end
		var content									= evalConstExpr( econtent );
		var path									= evalConstExpr( epath );
		var stringInterpolationToken	: String	= evalConstExpr( estringInterpolationToken );
		var isFullPath					: Bool		= evalConstExpr( eisFullPath );

		var pos	= Context.currentPos();

		if( path != null && !isFullPath ){
			path	= getFullPath( path );
		}

		var tpl	= new ftk.format.Template();
			tpl.parse( content );

		var parser	= new hscript.Parser();
			parser.identChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_$";	// $ added in order to get i.e. record-macros working
		var ast 	= null;
		try{
			ast	= parser.parseString( tpl.out );
		}
#if hscriptPos
		catch( e : hscript.Expr.Error ){
			if( path != null ){
				var a		= content.split( "\n" );
				var offset	= 0;
				for( i in 0...( e.line - 1 ) ){
					var line	= a[ i ];
					offset		+= line.length + 1;
				}
				pos	= Context.makePosition( { file : path, min : offset, max : offset } );
			}
			Context.fatalError( e.toString(), pos  );
		}
#end
		catch( e ){
			if( path != null ){
				pos	= Context.makePosition( { file : path, min : 0, max : 0 } );
			}
			Context.fatalError( e.message, pos );
		}

		var e	= new hscript.Macro( pos ).convert( ast );

		// Check String Interpolations (and report exact error line if `templatePos` defined and error occured)
		switch e.expr{
			case EBlock(a)	:
#if templatePos
				var exprsBuf	= [];
				var line		= 1;
#end
				for( ee in a ){
#if templatePos
					if( path != null ){
						line = checkExpr( ee, exprsBuf, line, content, path );
					}
#end
					checkStringInterpolation( ee, stringInterpolationToken );
				}
			case _ :
		}
		return e;
	}

#end

#if macro

#if templatePos
	static function checkExpr( expr : Expr, exprsBuf : Array<Expr>, line : Int, content : String, path : String ) : Int {
		var skip	= true;
		switch expr.expr {
			case EBlock( exprs )	:
				for( e in exprs ){
					line = checkExpr( e, exprsBuf, line, content, path );
				}
			case EIf(econd,eif,eelse)	: 
				line = checkExpr( econd, exprsBuf, line, content, path );
				line = checkExpr( eif, exprsBuf, line, content, path );
				if( eelse != null ){
					line = checkExpr( eelse, exprsBuf, line, content, path );
				}
			case ESwitch(e, cases, _):
				line = checkExpr( e, exprsBuf, line, content, path );
				for( c in cases ){
					for( val in c.values ){
						switch val.expr{
							case ECall(_, params):
								for( ee in params ){
									var ident	= ee.toString();
									var v		= macro var $ident : Dynamic = null;
									line		= checkExpr( v, exprsBuf, line, content, path );
								}
							case EConst(CIdent(s)) : 
								var c	= s.substr( 0, 1 );
								if( c == c.toLowerCase() ){
									var v	= macro var $s : Dynamic = null;
									line	= checkExpr( v, exprsBuf, line, content, path );
								}
							case _ : throw val.toString() + " Not implemented";
						}
					}
					if( c.expr != null ){
						line = checkExpr( c.expr, exprsBuf, line, content, path );
					}
				}
			case EFor(eit,eexpr)		:
				switch eit.expr {
					case EBinop(_,e1,e2)	: 
						var ident	= e1.toString();
						var v		= macro var $ident : Dynamic = null;
						line		= checkExpr( v, exprsBuf, line, content, path );
						line		= checkExpr( eexpr, exprsBuf, line, content, path );
					case _ :
						throw eexpr.toString() + " Not implemented";
				}
			case EWhile(econd, e, normalWhile)	:
				if( normalWhile ){
					line	= checkExpr( econd, exprsBuf, line, content, path );
					line	= checkExpr( e, exprsBuf, line, content, path );
				}else{
					line	= checkExpr( e, exprsBuf, line, content, path );
					line	= checkExpr( econd, exprsBuf, line, content, path );
				}
			case EBreak	:
				var rand	= Math.floor( Math.random() * 1000000 );
				var ident	= "_" + rand;
				var v 		= macro var $ident : Dynamic = null;
				line		= checkExpr( v, exprsBuf, line, content, path );
			case _ :
				skip	= false;
		}

		if( !skip ){
			exprsBuf.push( expr );
			var s 	= expr.toString();
			var len	= s.split( "\\n" ).length;
			try{
				line	+= len - 1;
				Context.typeExpr( macro $b{ exprsBuf.concat( [ macro null ] ) } ); // I add `macro null` at the end of the block to be typed to avoid compiler dilemma with if/else if without final else statement : `Void should be String` since the last block expression's type is the type of the whole block.
			}catch( ex ){
				var sourceLines	= content.split( "\n" );
				var offset		= 0;
				for( i in 0...( line - 1 ) ){
					var cline	= sourceLines[ i ];
					offset		+= cline.length + 1;
				}
				var pos	= Context.makePosition( { file : path, min : offset, max : offset } );
				Context.fatalError( ex.toString(), pos  );
			}
		}
		return line;
	}
#end

	static function checkStringInterpolation( e : Expr, stringInterpolationToken : String ){
		if( stringInterpolationToken == null ) stringInterpolationToken = Template.stringInterpolationToken;
		switch e.expr {
			case EConst( CString( s ) )	:
				if( s.indexOf( stringInterpolationToken ) != -1 ){
					s		= s.split( stringInterpolationToken ).join( "$" );
					e.expr	= MacroStringTools.formatString( s, e.pos ).expr;
				}
			case _ :
				ExprTools.iter( e, checkStringInterpolation.bind( _, stringInterpolationToken ) );
		}
	}

	/*  Automatic build function
	*	Usage : 
	* 	Add `--macro ftk.format.Template.buildTemplates()` into build file
	*	Add `-D hscriptPos` to report error line related to hscript interpreter/macro exprs generator (synthax errors)
	*	Add `-D templatePos` to report error line related to generated expressions
	*	
	*	@:template( "my/path/to/templateFile" ) public function myFunction( arg1, arg2... );
	*/

	public static function buildTemplates( ?stringInterpolationToken : String, ?templateMeta : String ){
		if( Context.definedValue( "hscript" ) == null ){
			Context.fatalError( "hscript needed to use ftk.format.Template and generate templates. Please add -lib hscript or another hscript like lib and the -D hscript define.", Context.currentPos() );
		}
		if( stringInterpolationToken != null ){
			Template.stringInterpolationToken	= stringInterpolationToken;
		}
		if( templateMeta != null ){
			Template.templateMeta	= templateMeta;
		}
		Compiler.addGlobalMetadata( "", '@:build( ftk.format.Template._build() )' );
	}

	static function _build() : Array<Field> {
		var fields	= Context.getBuildFields();
		for( field in fields ){
			switch field.kind{
				case FFun(f):
					if( f.expr == null ){
						for( meta in field.meta ){
							if( meta.name == ':$templateMeta' ){
								var param	= meta.params[ 0 ];
								if( param == null ){
									Context.fatalError( "Invalid meta. String path needed", field.pos  );
								}
								var path	= switch param.expr {
									case EConst( CString( s ) )	: s;
									case _						: 
										Context.fatalError( "Invalid meta. String path needed", field.pos  );
								}
								path	= getFullPath( path );
								
								var content = try{
									sys.io.File.getContent( path );
								}catch( e ){
									Context.fatalError( e.message, field.pos );
								}
								var pos		= Context.makePosition( { file : path, min : 0, max : 0 } );
								var expr	= macro @:pos( pos ) ftk.format.Template.buildFromString( $v{ content }, $v{ path }, null, true );
								f.expr	= expr;
							}
						}
					}
				case _ :
			}
		}
		return fields;
	}

	static function getFullPath( path : String ){
		var cl		= Context.getLocalClass().get();
		var clFile	= Context.getPosInfos( cl.pos ).file;
		var p		= new haxe.io.Path( clFile );
		return p.dir + "/" + path;
	}

	static function evalConstExpr( expr : Expr ) : Dynamic {
		return try{
			ExprTools.getValue( Context.getTypedExpr( Context.typeExpr( expr ) ) );
		}catch( e ){
			Context.fatalError( "Only constant expressions are allowed", expr.pos );
		}
	}

#end

}