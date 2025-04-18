package ftk.format.template;

import haxe.PosInfos;
import hscript.Expr;

using hscript.Tools;

/**
 * @version 2.1.2
 * @author filt3rek
 */

@:structInit
class StackItem{
	public var o		: String;
	public var f		: String;
	public var args		: Array<String>;
	public var curExpr	: String;
	public var pos		: PosInfos;

	public function toString(){
		return Std.string({
			o		: o,
			f		: f,
			args	: args,
			curExpr	: curExpr,
			pos		: pos,
		});
	}
}

class InterpError {
	public var native		(default,null)	: Error;
	public var source		(default,null)	: Null<String>;
	public var callStack	(default,null)	: Null<Array<StackItem>>;

	public function new( native : Error, ?source : String, ?callStack : Array<StackItem> ){
		this.native		= native;
		this.source		= source;
		this.callStack	= callStack;
	}

	public function toObject(){
		return {
			native		: native,
			source		: source,
			callStack	: callStack
		}
	}

	public function toString(){
#if hscriptPos
		return source != null ? native.toString() + " : " + source.split( "\n" )[ native.line -1 ] : native.toString();
#else
		return native;
#end
	}
}

// "_" added to prevent https://github.com/HaxeFoundation/haxe/issues/10820
@:allow( ftk.format.template.Interp )
class _HScriptInterp extends hscript.Interp{
	var useStrictVariableResolution	= true;

	override function fcall( o : Dynamic, f : Dynamic, args : Array<Dynamic> ) : Dynamic {
		try{
			return super.call( o, get( o, f ), args );
		}catch( e : InterpError ){
			e.callStack.unshift( ({ o : Std.string( o ), f : Std.string( f ), args : [ for( arg in args ) Std.string( arg ) ], curExpr : Std.string( curExpr.e ), pos : posInfos() }:StackItem) );
			throw e;
		}catch( e ){
			// Get errors infos
			throw new InterpError( #if hscriptPos new Error( #end ECustom( e.message )#if hscriptPos , null, null, "hscript", -1 )#end, ([ { o : Std.string( o ), f : Std.string( f ), args : [ for( arg in args ) Std.string( arg ) ], curExpr : Std.string( curExpr.e ), pos : posInfos() } ]:Array<StackItem>) );
		}
	}

	override function resolve( id : String ) : Dynamic {
		var l = locals.get( id );
		if( l != null )
			return l.r;
		var v = variables.get( id );
		if( v == null && !variables.exists( id ) && useStrictVariableResolution )
			error( EUnknownVariable( id ) );
		return v;
	}
}

class Interp {
	var hinterp			: _HScriptInterp;

	var parser			: Parser;
	var runtimePos		: Bool;

	var currentSource	: String;
	var sourcesStack	: Array<String>;	// inclusions' sources
	var callSources		: Array<String>;	// functions' calls sources

	public var useStrictVariableResolution	(get,set)	: Bool;	// gives null instead of throwing EUnknownVariable when resolving an unknown variable
	
	function set_useStrictVariableResolution( b : Bool ){
		return hinterp.useStrictVariableResolution	= b;
	}
	function get_useStrictVariableResolution(){
		return hinterp.useStrictVariableResolution;
	}

	/*
	*	Run-time shortcut working like Macro.build.buildFromString()
	*	Usage : 
	*	```
	*	public function myFunction( arg1, arg2... ){
	*		var x = "foo";
	*		...
	*		ftk.format.template.Interp.buildFromString( "::x:: is not bar" );	// foo is not bar
	*	}
	*	```
	*	@param	content	: source template
	*	@param	?ctx	: Set of fields to include in hscript context
	*/

	public static function buildFromString( content : String, ?ctx : {} ){
		return new Interp().execute( content, ctx );
	}

	/*  
	*	Run-time Interp's constructor
	*	
	*	@param	?runtimePos	: If set to true, it will manage source code if errors occurs, especially when using inclusions. true by dafault
	*	@param	?addStd		: If set to true, adds some standard haxe classes (Std, Math, Date, StringTools...)
	*	@param	?isStrict	: If set to false, it will be more permissive and allow access unknow variables for example
	*	@param	?parser		: If you want to use your own configuration's Parser
	*
	*	Add `-D hscriptPos` to report error line related to hscript interpreter exprs generator. A bit slower when set to true.
	*/

	public function new( runtimePos = true, addStd = false, isStrict = true, ?parser : Parser ) {
		this.runtimePos				= runtimePos;
		this.parser					= parser ?? new Parser();
		hinterp 					= new _HScriptInterp();
		useStrictVariableResolution	= isStrict;

		if( runtimePos ){
			sourcesStack	= [];
			callSources		= [];

			hinterp.variables.set( "__currentSource__", function( index ){
				currentSource	= callSources[ index ];
			} );
		}

		hinterp.variables.set( "__toString__", (o)->__toString__(o) );
		hinterp.variables.set( "__include__", function ( __source__ ){
			if( runtimePos ){	
				sourcesStack.push( currentSource );
				currentSource	= __source__;
			}

			var ret	= execute( __source__, true );

			if( runtimePos ){
				currentSource	= sourcesStack.pop();
			}
			return ret;
		} );

		if( addStd ){
			for( cname in Tools.stdClasses ){
				var path	= cname.split( "." );
				hinterp.variables.set( path[ path.length - 1 ], Type.resolveClass( cname ) );
			}
		}
	}

	public dynamic function __toString__( o : Null<Any> ) : String {
		return Std.string( o );
	}

	/*  
	*	Main function that interprets a template
	*	
	*	@param	source		: "native" template
	*	@param	ctx			: Set of fields to include in hscript context
	*	@param	isInclusion	: Used internally.
	*
	*	Add `-D hscriptPos` to report error line related to hscript interpreter exprs generator. A bit slower when set to true.
	*/

	public function execute( source : String, ?ctx : {}, isInclusion = false ) : String {
		if( runtimePos && !isInclusion ){
			currentSource	= source;
		}

		if( ctx == null )	ctx	= {};
		for( field in Reflect.fields( ctx ) ){
			hinterp.variables.set( field, Reflect.field( ctx, field ) );
		}

		try{
			var expr	= new hscript.Parser().parseString( parser.parse( source ) );
			if( runtimePos ){
				addSources( expr, source );
			}
			if( !isInclusion ){
				return hinterp.execute( expr );
			}else{
				return @:privateAccess hinterp.exprReturn( expr );
			}
		}catch( e : InterpError ){
			if( e.source == null && runtimePos )	throw new InterpError( e.native, runtimePos ? currentSource : null, e.callStack );
			throw e;
		}catch( e : Error ){
			throw new InterpError( e, runtimePos ? currentSource : null );
		}catch( e ){
#if hscriptPos
			var pos	= hinterp.posInfos();
			throw new InterpError( new Error( ECustom( e.message ), 0, 0, pos.fileName, pos.lineNumber ), runtimePos ? currentSource : null );
#else
			throw new InterpError( ECustom( e.message ), runtimePos ? currentSource : null );
#end
		}
	}

	//

	function addSources( expr : Expr, ?source : String, ?index : Int ){
		if( source != null ){
			callSources.push( source );
			index	= callSources.length - 1;
		}
		switch #if hscriptPos expr.e #else expr #end {
			case EFunction(args, e, name, ret):
				if( name == "__currentSource__" || name == "__include__" ){
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
				if( name == "__currentSource__" || name == "__include__" ){
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
}