package ftk.format.template;

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
 * @version 1.2.1
 * @author filt3rek
 */

#if ( hscriptPos )
class TemplateError {
	public var source	(default,null)	: String;
	public var native	(default,null)	: hscript.Expr.Error;

	public function new( source : String, native : hscript.Expr.Error ){
		this.source		= source;
		this.native		= native;
	}

	public function toString(){
		return '${ hscript.Printer.errorToString( native ) } : ${ source.split( "\n" )[ native.line -1 ] }';
	}
}
#end

class Template {

#if macro
	static var stringInterpolationToken	= "$";
	static var templateMeta				= "template";
#end

	var hinterp			: hscript.Interp;
	var currentSource	: String;

	public function new() {
		hinterp = new hscript.Interp();
		hinterp.variables.set( "__toString__", Std.string );
		hinterp.variables.set( "__variables__",  hinterp.variables );
	}

	public function execute( s : String, ?ctx : {} ) : String {
		try{
			if( currentSource == null ){
				currentSource	= s;
			}
			if( ctx == null )	ctx	= {};
			for( field in Reflect.fields( ctx ) ){
				hinterp.variables.set( field, Reflect.field( ctx, field ) );
			}
			hinterp.variables.set( "__inject__", function( s ){ 
				var oldSource	= currentSource;
				currentSource	= s;
				return execute( s );
				currentSource	= oldSource;
			} );
			return hinterp.execute( new hscript.Parser().parseString( s ) );
		}
#if hscriptPos
		catch( e : hscript.Expr.Error ){
			throw new TemplateError( currentSource, e );
		}
#end
	}

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

		var tpl	= new Template();

		var parser	= new hscript.Parser();
			parser.identChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_$";	// $ added in order to get i.e. record-macros working
		var ast 	= null;
		try{
			ast	= parser.parseString( new Parser().parse( content ) );
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
			Context.fatalError( "hscript needed to use ftk.format.template.Template and generate templates. Please add -lib hscript or another hscript like lib and the -D hscript define.", Context.currentPos() );
		}
		if( stringInterpolationToken != null ){
			Template.stringInterpolationToken	= stringInterpolationToken;
		}
		if( templateMeta != null ){
			Template.templateMeta	= templateMeta;
		}
		Compiler.addGlobalMetadata( "", '@:build( ftk.format.template.Template._build() )' );
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
								var expr	= macro @:pos( pos ) ftk.format.template.Template.buildFromString( $v{ content }, $v{ path }, null, true );
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