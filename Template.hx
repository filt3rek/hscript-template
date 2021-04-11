package ftk.format;

/**
 * ...
 * @author filt3rek
 */

using StringTools;

enum EToken{
	EText( s : String );
	EExpr( s : String );
	EDo( s : String );
	EIf( s : String );
	EElseIf( s : String );
	EElse;
	EFor( s : String );
	EEnd;
}
 
class Template {

	public static var SIGN		= ":";
	public static var IF		= "if";
	public static var ELSE		= "else";
	public static var ELSEIF	= "elseif";
	public static var FOR		= "for";
	public static var END		= "end";
	public static var DO		= "do";

	public var flow	: Array<EToken>;
	public var out	: String;		
	
	var buf	: String;
	
	public function new() {}

	public function parse( s : String ) {
		var iter	= null;
#if ( haxe_ver >= 4 ) 
		iter	= new haxe.iterators.StringKeyValueIteratorUnicode( s );
#else
		var a	= [];
		var s	= haxe.Utf8.encode( s );
		function f( n : Int ){
			a.push( { key : i++, value : n } );
		}
		haxe.Utf8.iter( s, f );
		iter	= a.iterator();
#end
		flow	= [];
		buf 	= "";
		var insideExpr	= false;
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
						flow.push( EText( buf ) );
						insideExpr 	= true;
					}
					buf = "";
				}else{
					buf += c + c2;
				}
			}else{
				buf += c;
			}
		}
		
		out			= 'var s="";';
		for( token in flow ){
			switch token {
				case EText( s ) :
					s	= s.split( '"' ).join( '\\"' );
					out += 's+="$s";';
				case EExpr( s ) : 
					out += 's+=$s;';
				case EIf( s ) 	: 
					out += 'if$s{';
				case EElseIf( s ) 	: 
					out += '}else if$s{';
				case EFor( s ) 	: 
					out += 'for$s{';
				case EDo( s ) 	: 
					out += '$s;';
				case EElse		: 
					out += '}else{';
				case EEnd		 : 
					out += '}';
				case _ :
			}
		}
		out	+= "return s;";
	}
}
