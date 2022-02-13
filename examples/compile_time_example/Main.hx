class Main{

	static function main(){
		var params	= php.Lib.hashOfAssociativeArray( php.SuperGlobal._GET );
		var title	= params.get( "title" );
		var content	= params.get( "content" );
		php.Lib.print( render( title, content ) );
	}

	@:template( "tpl/shell.mtt" )	static function render( ?title : String, ?content : String );
}