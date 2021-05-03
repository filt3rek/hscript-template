package ftk.format;

/**
 * ...
 * @author filt3rek
 */

using StringTools;

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
	EFor( s : String );
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
	public var IF		= "if";
	public var ELSE		= "else";
	public var ELSEIF	= "elseif";
	public var FOR		= "for";
	public var SWITCH	= "switch";
	public var CASE		= "case";
	public var END		= "end";
	public var DO		= "do";

	public var flow	: Array<ETemplateToken>;
	public var out	: UnicodeString;		
	
	var str	: String;
	var buf	: UnicodeString;
	
	public function new() {}

	public function parse( s : UnicodeString ) {
		var iter	= new haxe.iterators.StringKeyValueIteratorUnicode( s );

		str		= s;
		flow	= [];
		buf 	= "";
		var insideExpr		= false;
		var writeText		= true;
		while( true ){
			if( !iter.hasNext() ) break;
			var c	= String.fromCharCode( iter.next().value );
			if( c == SIGN ){
				if( !iter.hasNext() ) break;
				var c2	= String.fromCharCode( iter.next().value );
				if( c2 == SIGN ){
					if( insideExpr ){
						if( buf == ELSE ){
							flow.push( EElse );
						}else if( buf == END ){
							flow.push( EEnd );
						}else{
							if( buf.substr( 0, IF.length ).toLowerCase() == IF.toLowerCase() ){
								var next	= buf.charCodeAt( IF.length );
								if( next == " ".code || next == "\t".code || next == "\r".code || next == "\n".code || next == "(".code ){
									flow.push( EIf( buf.substr( IF.length ) ) );
								}else{
									flow.push( EExpr( buf ) );
								}
							}else if( buf.substr( 0, ELSEIF.length ).toLowerCase() == ELSEIF.toLowerCase() ){
								var next	= buf.charCodeAt( ELSEIF.length );
								if( next == " ".code || next == "\t".code || next == "\r".code || next == "\n".code || next == "(".code ){
									flow.push( EElseIf( buf.substr( ELSEIF.length ) ) );
								}else{
									flow.push( EExpr( buf ) );
								}
							}else if( buf.substr( 0, FOR.length ).toLowerCase() == FOR.toLowerCase() ){
								var next	= buf.charCodeAt( FOR.length );
								if( next == " ".code || next == "\t".code || next == "\r".code || next == "\n".code || next == "(".code ){
									flow.push( EFor( buf.substr( FOR.length ) ) );
								}else{
									flow.push( EExpr( buf ) );
								}
							}else if( buf.substr( 0, SWITCH.length ).toLowerCase() == SWITCH.toLowerCase() ){
								var next	= buf.charCodeAt( SWITCH.length );
								if( next == " ".code || next == "\t".code || next == "\r".code || next == "\n".code || next == "(".code ){
									flow.push( ESwitch( buf.substr( SWITCH.length ) ) );
									writeText		= false;
								}else{
									flow.push( EExpr( buf ) );
								}
							}else if( buf.substr( 0, CASE.length ).toLowerCase() == CASE.toLowerCase() ){
								var next	= buf.charCodeAt( CASE.length );
								if( next == " ".code || next == "\t".code || next == "\r".code || next == "\n".code || next == "(".code ){
									flow.push( ECase( buf.substr( CASE.length ) ) );
									writeText	= true;
								}else{
									flow.push( EExpr( buf ) );
								}
							}else if( buf.substr( 0, DO.length ).toLowerCase() == DO.toLowerCase() ){
								var next	= buf.charCodeAt( DO.length );
								if( next == " ".code || next == "\t".code || next == "\r".code || next == "\n".code || next == "{".code ){
									flow.push( EDo( buf.substr( DO.length + 1 ) ) );
								}else{
									flow.push( EExpr( buf ) );
								}
							}else{
								flow.push( EExpr( buf ) );
							}
						}
						insideExpr	= false;
					}else{
						if( writeText ){
							flow.push( EText( buf ) );
						}
						insideExpr 	= true;
					}
					buf = "";
				}else{
					buf = buf + c + c2;
				}
			}else{
				buf = buf + c;
			}
		}
		if( buf != null ){
			flow.push( EText( buf ) );
		}
		
		out			= 'var __s__="";';
		for( token in flow ){
			switch token {
				case EText( s ) :
					s	= s.split( '"' ).join( '\\"' );
					out = out + '__s__+="$s";';
				case EExpr( s ) : 
					if( s.startsWith( "*" ) && s.endsWith( "*" ) ){
						out = out + '/*__s__+=$s;*/';
					}else{
						out = out + '__s__+=$s;';
					}
				case EIf( s ) 	: 
					out = out + 'if($s){';
				case EElseIf( s ) 	: 
					out = out + '}else if($s){';
				case EFor( s ) 	: 
					out = out + 'for($s){';
				case EDo( s ) 	: 
					out = out + '$s;';
				case EElse		: 
					out = out + '}else{';
				case ESwitch( s )		: 
					out = out + 'switch($s){';
				case ECase( s )		: 
					out = out + 'case $s:';
				case EEnd		 : 
					out = out + '}';
				case _ :
			}
		}
		out	= out + "return __s__;";
		return out;
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
			var ret		: String =  interp.execute( ast );
			return ret;
		}
#if hscriptPos
		catch( e : hscript.Expr.Error ){
			var lines	= str.split( "\n" );
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
	macro public static function buildFromFile( path : String, ?stringInterpolationToken : String, ?isFullPath : Bool ) {
#if display
		return;
#end
		var pos		= haxe.macro.Context.currentPos();

		if( path != null && !isFullPath ){
			path	= getFullPath( path );
		}

		var content = try{
			sys.io.File.getContent( path );
		}catch( e ){
			haxe.macro.Context.fatalError( e.message, pos );
		}

		pos	= haxe.macro.Context.makePosition( { file : path, min : 0, max : 0 } );
		
		return macro @:pos( pos ) ftk.format.Template.buildFromString( $v{ content }, $v{ path }, $v{ stringInterpolationToken }, true );
	}

	macro public static function buildFromString( content : String, ?path : String, ?stringInterpolationToken : String, ?isFullPath : Bool ){
#if display
		return;
#end
		var pos	= haxe.macro.Context.currentPos();

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
				pos	= haxe.macro.Context.makePosition( { file : path, min : offset, max : offset } );
			}
			haxe.macro.Context.fatalError( e.toString(), pos  );
		}
#end
		catch( e ){
			if( path != null ){
				pos	= haxe.macro.Context.makePosition( { file : path, min : 0, max : 0 } );
			}
			haxe.macro.Context.fatalError( e.message, pos );
		}

		var e	= new hscript.Macro( pos ).convert( ast );
		
		// Check String Interpolations (and report exact error line if `templatePos` defined and error occured)
		switch e.expr{
			case EBlock(a)	:
#if templatePos
				var line		= 1;
				var exprsBuf	= [];
#end
				for( ee in a ){
#if templatePos
					if( path != null ){
						exprsBuf.push( ee );
						var s 	= haxe.macro.ExprTools.toString( ee );
						try{
							var len	= s.split( "\\n" ).length;
							line	+= len - 1;
							haxe.macro.Context.typeExpr( macro $b{ exprsBuf.concat( [ macro null ] ) } ); // I add `macro null` at the end of the block to be typed to avoid compiler dilemma with if/else if without final else statement : `Void should be String` since the last block expression's type is the type of the whole block.
						}catch( ex ){
							var sourceLines	= content.split( "\n" );
							var offset	= 0;
							for( i in 0...( line - 1 ) ){
								var cline	= sourceLines[ i ];
								offset		+= cline.length + 1;
							}
							var pos	= haxe.macro.Context.makePosition( { file : path, min : offset, max : offset } );
							haxe.macro.Context.fatalError( ex.toString(), pos  );
						}
					}
#end
					haxe.macro.ExprTools.iter( ee, checkStringInterpolation.bind( _, stringInterpolationToken ) );
				}
			case _ :
		}
		
		return e;
	}

#end

#if macro

	static function checkStringInterpolation( e : haxe.macro.Expr, stringInterpolationToken : String ){
		if( stringInterpolationToken == null ) stringInterpolationToken = Template.stringInterpolationToken;
		switch e.expr {
			case EConst( CString( s ) )	:
				if( s.indexOf( stringInterpolationToken ) != -1 ){
					s		= s.split( stringInterpolationToken ).join( "$" );
					e.expr	= haxe.macro.MacroStringTools.formatString( s, e.pos ).expr;
				}
			case _ :
				haxe.macro.ExprTools.iter( e, checkStringInterpolation.bind( _, stringInterpolationToken ) );
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
		if( stringInterpolationToken != null ){
			Template.stringInterpolationToken	= stringInterpolationToken;
		}
		if( templateMeta != null ){
			Template.templateMeta	= templateMeta;
		}
		haxe.macro.Compiler.addGlobalMetadata( "", '@:build( ftk.format.Template._build() )' );
	}

	static function _build() : Array<haxe.macro.Expr.Field> {
		var fields	= haxe.macro.Context.getBuildFields();
		for( field in fields ){
			switch field.kind{
				case FFun(f):
					if( f.expr == null ){
						for( meta in field.meta ){
							if( meta.name == ':$templateMeta' ){
								var param	= meta.params[ 0 ];
								if( param == null ){
									haxe.macro.Context.fatalError( "Invalid meta. String path needed", field.pos  );
								}
								var path	= switch param.expr {
									case EConst( CString( s ) )	: s;
									case _						: 
										haxe.macro.Context.fatalError( "Invalid meta. String path needed", field.pos  );
								}
								path	= getFullPath( path );
								
								var content = try{
									sys.io.File.getContent( path );
								}catch( e ){
									haxe.macro.Context.fatalError( e.message, field.pos );
								}
								var pos		= haxe.macro.Context.makePosition( { file : path, min : 0, max : 0 } );
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
		var cl		= haxe.macro.Context.getLocalClass().get();
		var clFile	= haxe.macro.Context.getPosInfos( cl.pos ).file;
		var p		= new haxe.io.Path( clFile );
		return p.dir + "/" + path;
	}

#end

}
