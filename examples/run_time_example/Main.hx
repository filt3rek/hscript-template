class Main{

	static function main(){
		var params	= php.Lib.hashOfAssociativeArray( php.SuperGlobal._GET );
		var title	= params.get( "title" );
		var content	= params.get( "content" );

		var fileContent	= sys.io.File.getContent( "tpl/shell.mtt" );

		var tpl	= new ftk.format.template.Template();
		var out	= tpl.execute( new ftk.format.template.Parser().parse( fileContent ), { title : title, content : content } );

		php.Lib.print( out );
	}
}