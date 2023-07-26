package ftk.format.template;

import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Compiler;
import haxe.macro.MacroStringTools;
import hscript.Macro;

using StringTools;
using ftk.Strings;
using haxe.macro.ExprTools;

/**
 * @version 2.1.2
 * @author filt3rek
 */

class Macro{
#if macro
	static var templateMeta		= ":template";
	static var processedTypes	= [];

	// Init macro

	/*  
	*	Automatic global build function
	*	The function will build all functions like that : `@:template( "my/path/to/templateFile" ) public function myFunction( arg1, arg2... );` in every types defined by `pathFilter`
	*	Usage : 
	* 	Add `--macro ftk.format.Macro.buildTemplates()` into the .hxml build file
	*
	*	@param	pathFilter		: dot path to filter where the `@:build` will be added. `""` by default
	*	@param	recursive		: If `pathFilter` is the empty String `""` it matches everything (if `recursive = true`) or only top-level types (if `recursive = false`). `false` by default
	*	@param	templateMeta	: `:template` by default
	*
	*	Add `-D hscriptPos` to report error line related to hscript macro exprs generator
	*	Add `-D hscript_template_macro_pos` to report error line related to generated expressions
	*/

	public static function buildTemplates( paths : Array<String>, ?ignore : Array<String>, ?templateMeta : String, ?pos : haxe.PosInfos ){
#if hscript_template_build_trace
		trace( pos.fileName );
#end
		if( Context.definedValue( "hscript" ) == null ){
			Context.fatalError( "hscript needed to use ftk.format.template.Macro and generate templates. Please add -lib hscript.", Context.currentPos() );
		}
		if( templateMeta != null ){
			Macro.templateMeta	= templateMeta;
		}
		addGlobalMetadata( '@:build( ftk.format.template.Macro.build() )', paths, ignore );
	}

	public static function addGlobalMetadata( meta:String, paths : Array<String>, ?ignore : Array<String> ){
		processModule( function( cl ) haxe.macro.Compiler.addGlobalMetadata( cl, meta, false ), paths, ignore );
	}

	// `my.exact.Class` or `my.not_recurive.package` or `my.recursive.package.`
	static function processModule( f : String->Void, paths : Array<String>, ?ignore : Array<String> ) {
		switch Context.definedValue( "display" ) {
			case null, "usage"	:
			case _				: return;
		}
		ignore ??= [];
		var classPaths = Context.getClassPath();
		for( i in 0...classPaths.length ) {
			var cp = classPaths[ i ].split( "\\" ).join( "/" );
			if( cp.endsWith( "/" ) )
				cp = cp.substr( 0, -1 );
			if ( cp == "" )
				cp = ".";
			classPaths[ i ] = cp;
		}
		function checkDir( path : String, pack : String, recursive : Bool ){
			if( !sys.FileSystem.exists( path ) ){
				return;
			}
			for( file in sys.FileSystem.readDirectory( path ) ){
				if( sys.FileSystem.isDirectory( path + "/" + file ) && recursive ){
					checkDir( path + "/" + file, pack == "" ? file : pack + "." + file, recursive );
				}else{
					if( file == "import.hx" || !file.endsWith( ".hx" ) || file.substr( 0, file.length - 3 ).indexOf( "." ) > -1 )
						continue;
					var module	= ( pack == "" ? "" : pack + "." ) + file.substr( 0, -3 );
					if( paths.indexOf( module ) > -1 ){
						f( module );
					}else{
						for( gpath in paths ){
							if( module.indexOf( gpath ) > -1 && ignore.indexOf( module ) == -1 ){
								var skip	= false;
								for( gignore in ignore ){
									if( module.indexOf( gignore ) > -1 ){
										if( gignore.endsWith( "." ) ){
											skip	= true;
										}else{
											var apack	= module.split( "." );
											apack.pop();
											if( gignore == apack.join( "." ) ){
												skip = true;
											}
										}
									}
								}
								if( !skip ){
									f( module );
								}
							}
						}
					}
				}
			}
		}
		var _paths	= [];
		for( path in paths ){
			var split		= path.split( "." );
			var firstChar	= split[ split.length - 1 ].charAt( 0 );
			if( firstChar != "" && firstChar == firstChar.toUpperCase() ){
				split.pop();
				path	= split.join( "." );
				if( _paths.indexOf( path ) == -1 ){
					_paths.push( path );
				}
			}else{
				if( _paths.indexOf( path ) == -1 ){
					_paths.push( path );
				}
			}
		}
		for( cp in classPaths ) {
			for( path in _paths ){
				var recursive	= false;
				if( path.endsWith( "." ) ) {
					path	= path.substr( 0, -1 );
					recursive	= true;
				}
				var p = path == '' ? cp : cp + "/" + path.split( "." ).join( "/" );
				checkDir( p, path, recursive );
			}
		}
	}

	// Build macro

	/*  
	*	Automatic per-type build function
	*	The function will build all functions like that : `@:template( "my/path/to/templateFile" ) public function myFunction( arg1, arg2... );` in the wanted type
	*	Usage : 
	* 	Add `@:build( ftk.format.template.Macro.build() )` at the type where you want to proceed all `@:template` functions
	*
	*	Add `-D hscriptPos` to report error line related to hscript macro exprs generator
	*	Add `-D hscript_template_macro_pos` to report error line related to generated expressions
	*/

	public static function build() : Array<Field> {
		var tname	= switch Context.getLocalType(){
			case 	TInst(_.toString()=>s,_), TAbstract(_.toString()=>s,_)	: s;
			case _	: null;
		}
		if( tname == null )	return null;
		if( processedTypes.indexOf( tname ) > -1 )	return null;
		processedTypes.push( tname );
#if hscript_template_build_trace
		trace( "Processing : " + tname );
#end
		var fields	= Context.getBuildFields();
		for( field in fields ){
			switch field.kind{
				case FFun(f):
					if( f.expr == null ){
						for( meta in field.meta ){
							if( meta.name == templateMeta ){
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
								var expr	= macro @:pos( pos ) ftk.format.template.Macro.buildFromString( $v{ content }, $v{ path }, true );
								f.expr	= expr;
							}
						}
					}
				case _ :
			}
		}
		return fields;
	}
#end

	// Expr macro
	
	/*  
	*	Manual function that builds the template from a file
	*	Usage : 
	*	```
	*	public function myFunction( arg1, arg2... ){
	*		var x = "foo";
	*		...
	*		ftk.format.template.Macro.buildFromFile( "my/path/to/templateFile" );
	*	}
	*	```
	*	@param	path		: path to the file that contains the template's source
	*	@param	?isFullPath	: relative to the class (false) or to the project (true)
	*
	*	Add `-D hscriptPos` to report error line related to hscript macro exprs generator
	*	Add `-D hscript_template_macro_pos` to report error line related to generated expressions
	*/

	macro public static function buildFromFile( path : String, ?isFullPath : Bool ) {
#if display
		return;
#end
		var pos		= Context.currentPos();

		if( !isFullPath ){
			path	= getFullPath( path );
		}

		var content = try{
			sys.io.File.getContent( path );
		}catch( e ){
			Context.fatalError( e.message, pos );
		}

		pos	= Context.makePosition( { file : path, min : 0, max : 0 } );
		
		return macro @:pos( pos ) ftk.format.template.Macro.buildFromString( $v{ content }, $v{ path }, true );
	}

	/*  
	*	Manual function that builds the template from a string
	*	Usage : 
	*	```
	*	public function myFunction( arg1, arg2... ){
	*		var x = "foo";
	*		...
	*		ftk.format.template.Macro.buildFromString( "::x:: is not bar" );	// foo is not bar
	*	}
	*	```
	*	@param	content		: source template
	*	@param	?path		: path to the file that contains the template's source
	*	@param	?isFullPath	: relative to the class (false) or to the project (true)
	*
	*	Add `-D hscriptPos` to report error line related to hscript macro exprs generator
	*	Add `-D hscript_template_macro_pos` to report error line related to generated expressions
	*/

	macro public static function buildFromString( content : String, ?path : String, ?isFullPath : Bool ){
#if display
		return;
#end
		var pos	= Context.currentPos();

		if( path != null && !isFullPath ){
			path	= getFullPath( path );
		}

		var parser	= new hscript.Parser();
			parser.identChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_$";	// $ added in order to get i.e. record-macros working
		var ast 	= null;
		try{
			ast	= parser.parseString( new Parser().parse( content ) );
		}
#if ( hscript_template_macro_pos && hscriptPos )
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

		// Check string interpolations (and report exact error line if `hscript_template_macro_pos` defined and error occured)
		switch e.expr{
			case EBlock(a)	:
#if hscript_template_macro_pos
				var exprsBuf	= [];
				var line		= 1;
#end
				for( ee in a ){
#if hscript_template_macro_pos
					if( path != null ){
						line = checkExpr( ee, exprsBuf, line, content, path );
					}
#end
					checkStringInterpolation( ee );
				}
			case _ :
		}
		return e;
	}

#if macro
#if hscript_template_macro_pos
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
									var v		= macro var $ident = null;
									line		= checkExpr( v, exprsBuf, line, content, path );
								}
							case EConst(CIdent(s)) : 
								var c	= s.substr( 0, 1 );
								if( c == c.toLowerCase() ){
									var v	= macro var $s = null;
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
						var v		= macro var $ident = ([ for( i in ($e2:Array<Dynamic>) ) i ])[ 0 ];
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
				var v 		= macro var $ident = null;
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

	static function checkStringInterpolation( e : Expr ){
		switch e.expr {
			case EConst( CString( s ) )	:
				e.expr	= MacroStringTools.formatString( s, e.pos ).expr;
			case _ :
				e.iter( checkStringInterpolation );
		}
	}

	// Helper

	static function getFullPath( path : String ){
		var cl		= Context.getLocalClass().get();
		var clFile	= Context.getPosInfos( cl.pos ).file;
		var p		= new haxe.io.Path( clFile );
		return ( p.dir != null ? p.dir + "/" : "" ) + path;
	}
#end
}