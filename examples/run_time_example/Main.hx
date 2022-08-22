class Main{

	static function main(){
		var params	= php.Lib.hashOfAssociativeArray( php.SuperGlobal._GET );
		var title	= params.get( "title" );
		var content	= params.get( "content" );

		var fileContent	= sys.io.File.getContent( "tpl/shell.mtt" );

		var interp	= new ftk.format.template.Interp();
		var out		= interp.execute( new ftk.format.template.Parser().parse( fileContent ), { title : title, content : content } );

		// Or you can use here this shurtcut
		// var out	= ftk.format.template.Interp.buildFromString( fileContent, { title : title, content : content } );

		php.Lib.print( out );
	}
}