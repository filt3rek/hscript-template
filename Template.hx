package ftk.format;

/**
 * ...
 * @author filt3rek
 */

using StringTools;

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

	public static var SIGN		= ":";
	public static var IF		= "if";
	public static var ELSE		= "else";
	public static var ELSEIF	= "elseif";
	public static var FOR		= "for";
	public static var SWITCH	= "switch";
	public static var CASE		= "case";
	public static var END		= "end";
	public static var DO		= "do";

	public var flow	: Array<ETemplateToken>;
	public var out	: UnicodeString;		
	
	var buf	: UnicodeString;
	
	public function new() {}

	public function parse( s : UnicodeString ) {
		var iter	= null;
#if ( haxe_ver >= 4 ) 
		iter	= new haxe.iterators.StringKeyValueIteratorUnicode( s );
#else
		var a	= [];
		var i	= 0;
		var s	= haxe.Utf8.encode( s );
		function f( n : Int ){
			a.push( { key : i++, value : n } );
		}
		haxe.Utf8.iter( s, f );
		iter	= a.iterator();
#end
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
	}

	//	Compile-time templates
	
	/*  Manual build function
	*	Usage : @:template( "my/path" ) public function myFunction( arg1, arg2... ){
	*		ftk.format.Template.build();
	*	}
	*/

	macro public static function build() {
#if display
		return;
#end
		var pos		= haxe.macro.Context.currentPos();

		var lcl		= haxe.macro.Context.getLocalClass();
		var smethod	= haxe.macro.Context.getLocalMethod();
		var cl		= lcl.get();
		var method	= null;
		for( field in cl.statics.get().concat( cl.fields.get() ) ){
			if( field.name == smethod ){
				method	= field;
				break;
			}
		}
		
		var meta	= method.meta.extract( ":template" )[ 0 ];
		if( meta == null ){
			haxe.macro.Context.fatalError( "Template meta not found. @:template( \"my/path\" ) needed", pos  );
		}

		var spath	= switch meta.params[ 0 ].expr {
			case EConst( CString( s ) )	: s;
			case _						: 
				haxe.macro.Context.fatalError( "Invalid meta, String path needed", pos  );
				null;
		}

		var clFile	= haxe.macro.Context.getPosInfos( cl.pos ).file;
		var p		= new haxe.io.Path( clFile );
		var path	= p.dir + "/" + spath;
		
		var content = sys.io.File.getContent( path );

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
			var a		= content.split( "\n" );
			var offset	= 0;
			for( i in 0...( e.line - 1 ) ){
				var line	= a[ i ];
				offset		+= line.length + 1;
			}
			var pos	= haxe.macro.Context.makePosition( { file : path, min : offset, max : offset } );
			haxe.macro.Context.fatalError( e.toString(), pos  );
		}
		#end
		catch( e ){
			var pos	= haxe.macro.Context.makePosition( { file : path, min : 0, max : 0 } );
			haxe.macro.Context.fatalError( e.message, pos );
		}
		
		return new hscript.Macro( pos ).convert( ast );
	}

#if macro

	/*  Automatic build 
	*	Usage : 
	* 	Add `--macro ftk.format.Template.buildTemplates()` into build file
	*	And `-D hscriptPos` to report error positions
	*	
	*	@:template( "my/path" ) public function myFunction( arg1, arg2... );
	*/

	public static function buildTemplates(){
		haxe.macro.Compiler.addGlobalMetadata( "", "@:build( ftk.format.Template._build() )" );
	}

	static function _build() : Array<haxe.macro.Expr.Field> {
		var fields	= haxe.macro.Context.getBuildFields();
		for( field in fields ){
			switch field.kind{
				case FFun(f):
					if( f.expr == null ){
						for( meta in field.meta ){
							if( meta.name == ":template" ){
								f.expr	= macro @:pos( field.pos ) ftk.format.Template.build();		
							}
						}
					}
				case _ :
			}
		}
		return fields;
	}

#end

}
