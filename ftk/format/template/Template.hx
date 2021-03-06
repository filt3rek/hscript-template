package ftk.format.template;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Compiler;
import haxe.macro.ExprTools;
import haxe.macro.MacroStringTools;
import hscript.Macro;
#else
import hscript.Expr;
import hscript.Interp;
import hscript.Tools;
#end

using StringTools;
#if macro
using haxe.macro.ExprTools;
#else
using hscript.Tools;
#end

/**
 * @version 1.2.4
 * @author filt3rek
 */

#if !macro
class TemplateError {
	public var source	(default,null)	: Null<String>;
	public var native	(default,null)	: Error;

	public function new( native : Error, ?source : String ){
		this.native		= native;
		this.source		= source;
	}

	public function toString(){
#if hscriptPos
		return source != null ? native.toString() + " : " + source.split( "\n" )[ native.line -1 ] : native.toString();
#else
		return native;
#end
	}
}
#end

class Template {

	static var stdClasses	= [ "Std", "Math", "Date", "StringTools", "DateTools", "Lambda", "haxe.ds.StringMap", "haxe.ds.IntMap", "haxe.ds.ObjectMap" ];

#if macro
	static var templateMeta		= ":template";
	static var processedTypes	= [];
#else

	/******************************   Run-time templates   **************************************/

	var hinterp			: Interp;

	var runtimePos		: Bool;
	var currentSource	: String;

	var sourcesStack	: Array<String>;	// inclusions' sources
	var aSources		: Array<String>;	// functions' calls sources

	/*  
	*	Run-time Template's constructor
	*	
	*	@param	?runtimePos	: If set to true, it will manage source code if errors occurs, especially when using inclusions. true by dafault
	*	@param	?addStd		: If set to true, adds some standard haxe classes (Std, Math, Date, StringTools...)
	*
	*	Add `-D hscriptPos` to report error line related to hscript interpreter exprs generator. A bit slower when set to true.
	*/

	public function new( runtimePos = true, addStd = false ) {
		this.runtimePos	= runtimePos;
		hinterp 		= new Interp();

		if( runtimePos ){
			sourcesStack	= [];
			aSources		= [];
			hinterp.variables.set( "__currentSource__", function( index ){
				currentSource	= aSources[ index ];
			} );
		}

		hinterp.variables.set( "__toString__", Std.string );
		hinterp.variables.set( "__hscriptSource__", function ( __hscriptSource__ ){
			if( runtimePos ){	
				sourcesStack.push( currentSource );
				currentSource	= __hscriptSource__;
			}

			var ret	= execute( __hscriptSource__, true );

			if( runtimePos ){
				currentSource	= sourcesStack.pop();
			}
			return ret;
		} );

		if( addStd ){
			for( cname in stdClasses ){
				var path	= cname.split( "." );
				hinterp.variables.set( path[ path.length - 1 ], Type.resolveClass( cname ) );
			}
		}
	}

	/*  
	*	Main function that generates a template
	*	
	*	@param	hscriptSource	: hscript source code generated by template's Parser output
	*	@param	?ctx			: Set of fields to include in hscript context
	*	@param	?isInclusion	: Used internally.
	*
	*	Add `-D hscriptPos` to report error line related to hscript interpreter exprs generator. A bit slower when set to true.
	*/

	public function execute( hscriptSource : String, ?ctx : {}, isInclusion = false ) : String {
		if( runtimePos && !isInclusion ){
			currentSource	= hscriptSource;
		}
		if( ctx == null )	ctx	= {};
		for( field in Reflect.fields( ctx ) ){
			hinterp.variables.set( field, Reflect.field( ctx, field ) );
		}
		
		var expr	= new hscript.Parser().parseString( hscriptSource );
		if( runtimePos ){
			addSources( expr, hscriptSource );
		}
		try{
			if( !isInclusion ){
				return hinterp.execute( expr );
			}else{
				return @:privateAccess hinterp.exprReturn( expr );
			}
		}catch( e : TemplateError ){
			throw e;
		}catch( e : Error ){
			throw new TemplateError( e, runtimePos ? currentSource : null );
		}catch( e ){
#if hscriptPos
			var pos	= hinterp.posInfos();
			throw new TemplateError( new Error( ECustom( e.message ), 0, 0, pos.fileName, pos.lineNumber ), runtimePos ? currentSource : null );
#else
			throw new TemplateError( ECustom( e.message ), runtimePos ? currentSource : null );
#end
		}
	}

	/*  
	*	Helper function that "safetly" includes a template into another template
	*	
	*	@param	hscriptSource	: hscript source code generated by template's Parser output
	*
	*	Add `-D hscriptPos` to report error line related to hscript interpreter exprs generator. A bit slower when set to true.
	*/

	public function include( hscriptSource : String ){
		return execute( '__hscriptSource__( \'__s__+=${ escapeQuotes( hscriptSource ) }\' );', true );
	}

	//

	function addSources( expr : Expr, ?hscriptSource : String, ?index : Int ){
		if( hscriptSource != null ){
			aSources.push( hscriptSource );
			index	= aSources.length - 1;
		}
		switch #if hscriptPos expr.e #else expr #end {
			case EFunction(args, e, name, ret):
				if( name == "__currentSource__" || name == "__hscriptSource__" ){
					return;
				}else if( name == "__toString__"  ){
					expr.iter( addSources.bind(_, null, index ) );
					return;
				}

				switch #if hscriptPos e.e #else e #end {
					case EBlock( a )	: 
						a.unshift( ECall( EIdent( "__currentSource__" ).mk( e ), [ EConst( CInt( index ) ).mk( e ) ] ).mk( e ) );
					case _	:
				}
				e.iter( addSources.bind(_, null, index ) );

			case ECall(e, params):
				var name	= switch #if hscriptPos e.e #else e #end{
					case EIdent(v):	v;
					case _	: null;
				}
				if( name == "__currentSource__" || name == "__hscriptSource__" ){
					return;
				}else if( name == "__toString__"  ){
					expr.iter( addSources.bind(_, null, index ) );
					return;
				}
				
				var tmpName			= "call_" + Math.round( Math.random() * 1000 );
				
				var ecall	= ECall( e, params ).mk( expr );
				var eblock	= EBlock([ 
					EVar( tmpName, null, ecall ).mk( expr ),
					ECall( EIdent( "__currentSource__" ).mk( expr ), [ EConst( CInt( index ) ).mk( expr ) ] ).mk( expr ),
					EIdent( tmpName ).mk( expr ),
				]);
				#if hscriptPos expr.e #else expr #end	= eblock;
				ecall.iter( addSources.bind(_, null, index ) );
			case _	: 
				expr.iter( addSources.bind(_, null, index ) );
		}
	}

	//

	public static inline function escapeQuotes( s : String ){
		return s.split( '"' ).join( '\\"' ).split( "'" ).join( "\\'" );
	}
#end

	/****   Compile-time templates   ****/

	// Init macro

	/*  
	*	Automatic global build function
	*	The function will build all functions like that : `@:template( "my/path/to/templateFile" ) public function myFunction( arg1, arg2... );` in every types defined by `pathFilter`
	*	Usage : 
	* 	Add `--macro ftk.format.Template.buildTemplates()` into the .hxml build file
	*
	*	@param	pathFilter		: dot path to filter where the `@:build` will be added. `""` by default
	*	@param	recursive		: If `pathFilter` is the empty String `""` it matches everything (if `recursive = true`) or only top-level types (if `recursive = false`). `false` by default
	*	@param	templateMeta	: `:template` by default
	*
	*	Add `-D hscriptPos` to report error line related to hscript macro exprs generator
	*	Add `-D hscript_template_macro_pos` to report error line related to generated expressions
	*/

	public static function buildTemplates( pathFilter = "", recursive = false, ?templateMeta : String, ?pos : haxe.PosInfos ){
#if macro
#if hscript_template_build_trace
		trace( pos.fileName );
#end
		if( Context.definedValue( "hscript" ) == null ){
			Context.fatalError( "hscript needed to use ftk.format.template.Template and generate templates. Please add -lib hscript.", Context.currentPos() );
		}
		if( templateMeta != null ){
			Template.templateMeta	= templateMeta;
		}
		Compiler.addGlobalMetadata( pathFilter, '@:build( ftk.format.template.Template.build() )', recursive );
#end
	}

	/*
	*	This function will add and keep all the std classes to be available at run-time (when addStd is set at true in the Template constructor)
	*/

	public static function addStd(){
#if macro
		for( cname in stdClasses ){
			haxe.macro.Compiler.addMetadata( "@:keep", cname );
		}
#end
	}

	// Build macro

	/*  
	*	Automatic per-type build function
	*	The function will build all functions like that : `@:template( "my/path/to/templateFile" ) public function myFunction( arg1, arg2... );` in the wanted type
	*	Usage : 
	* 	Add `@:build( ftk.format.template.Template.build() )` at the type where you want to proceed all `@:template` functions
	*
	*	Add `-D hscriptPos` to report error line related to hscript macro exprs generator
	*	Add `-D hscript_template_macro_pos` to report error line related to generated expressions
	*/

#if macro
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
								var expr	= macro @:pos( pos ) ftk.format.template.Template.buildFromString( $v{ content }, $v{ path }, true );
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
	*		ftk.format.template.Template.buildFromFile( "my/path/to/templateFile" );
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

		trace( path );

		if( !isFullPath ){
			path	= getFullPath( path );
		}

		var content = try{
			sys.io.File.getContent( path );
		}catch( e ){
			Context.fatalError( e.message, pos );
		}

		pos	= Context.makePosition( { file : path, min : 0, max : 0 } );
		
		return macro @:pos( pos ) ftk.format.template.Template.buildFromString( $v{ content }, $v{ path }, true );
	}

	/*  
	*	Manual function that builds the template from a string
	*	Usage : 
	*	```
	*	public function myFunction( arg1, arg2... ){
	*		var x = "foo";
	*		...
	*		ftk.format.template.Template.buildFromString( "::x:: is not bar" );	// foo is not bar
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

		var e	= new Macro( pos ).convert( ast );

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

	//

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