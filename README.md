# hscript-template
Little run-time and compile-time template system based on https://github.com/HaxeFoundation/hscript

A little class that “generates” a “haxe source” which you can use with hscript to get a template system working like tink_template.
It can be improved of course but I stop here for now I get all for my needs.
The synthax is almost the same as in tink_template and it supports expressions output, if, else, elseif, switch/case, for statements “do” and comments.
I didn’t wrote any error handling because hscript does that but you can see how catch errors at the end of this document.
~~This class could directly generate hscript AST expressions, but I’ve done that quickly, I have no time to look deeper into hscript for now.~~
It does play directly with ast when generating compile-time templates.

Here is an example of a working template :
```
Hello "::ctx.recipient.name::", your main company is : ::ctx.recipient.companies[ 0 ].name::
::if( !ctx.recipient.male )::Bonjour Madame !::else::Bonjour Monsieur !::end::
You work in these companies : ::ctx.recipient.companies.map( function( c ) return c.name ).join( ', ' )::
Here are your companies :
::do var rand = Math.rand()::
::for( company in ctx.recipient.companies )::
	::if( rand < .2 )::
		::company.name.toLowerCase()::
	::elseif( rand > .7 )::
		::company.name.toUpperCase()::
	::else::
		::company.name::
	::end::
::end::
```

You can also customize the sign used to delimitate expressions and the keywords as if, else, for, end and do.
So now you can wrtie templates like that (like in the awful WINDEV-FR :rofl: ) :
```
Hello "**ctx.recipient.name**", your main company is : **ctx.recipient.companies[ 0 ].name**
**si( !ctx.recipient.male )**Bonjour Madame !**sinon**Bonjour Monsieur !**fin**
You work in these companies : **ctx.recipient.companies.map( function( c ) return c.name ).join( ', ' )**
Here are your companies :
**pose var rand = Math.random()**
**boucle( company in ctx.recipient.companies )**
	**si( rand < .2 )**
		**company.name.toLowerCase()**
	**ou_si( rand > .7 )**
		**company.name.toUpperCase()**
	**sinon**
		**company.name**
	**fin**
**fin**
```
This is the result you get and give to eat to hscript : 
```haxe
var s="";s+="Hello \"";s+=ctx.recipient.name;s+="\", your main company is : ";s+=ctx.recipient.companies[ 0 ].name;s+="
";if( !ctx.recipient.male ){s+="Bonjour Madame !";}else{s+="Bonjour Monsieur !";}s+="
You work in these companies : ";s+=ctx.recipient.companies.map( function( c ) return c.name ).join( ', ' );s+="
Here are your companies :
";var rand = Math.rand();s+="
";for( company in ctx.recipient.companies ){s+="
	";if( rand < .2 ){s+="
		";s+=company.name.toLowerCase();s+="
	";}else if(() rand > .7 ){s+="
		";s+=company.name.toUpperCase();s+="
	";}else{s+="
		";s+=company.name;s+="
	";}s+="
";}return s;
```
At the begining I've written a "pretty" mode to output with indents and newlines but I don't see the need at the end so I removed that.
Here is a full example https://try.haxe.org/#B3eE1d01 :
```haxe
class Test {
	static function main() {
          var s = "Hello \"**ctx.recipient.name**\", your main company is : **ctx.recipient.companies[ 0 ].name**
      **si( !ctx.recipient.male )**Bonjour Madame !**sinon**Bonjour Monsieur !**fin**
      You work in these companies : **ctx.recipient.companies.map( function( c ) return c.name ).join( ', ' )**
      Here are your companies :
      **pose var rand = Math.random()**
      **boucle( company in ctx.recipient.companies )**
        **si( rand < .2 )**
		**company.name.toLowerCase()**
	**ou_si( rand > .7 )**
		**company.name.toUpperCase()**
	**sinon**
		**company.name**
	**fin**
      **fin**";

          Template.SIGN		= "*";
          Template.DO		= "pose";
          Template.IF		= "si";
	  Template.ELSEIF	= "ou_si";
          Template.ELSE		= "sinon";
          Template.FOR		= "boucle";
          Template.END		= "fin";
          var tpl		= new Template();
          tpl.parse( s );
          trace( tpl.out );

          var ctx = {
            recipient: {
              name: "Mrs. Annie Cordy",
              male: false,
              companies: [{name: "Company 1"}, {name: "Company 2"}]
            }
          }

          var parser  = new hscript.Parser();
          var ast     = parser.parseString( tpl.out );
          var interp  = new hscript.Interp();
          interp.variables.set( "ctx", ctx );
          interp.variables.set( "Math", Math );
          var ret     =  interp.execute( ast );
          trace( ret );
	}
}
```
## Error handling

For example if the template has an error like that :
```
1.  Hello "::ctx.recipient.name::", your main company is : ::ctx.recipient.companies[ 0 ].name::
2.  ::if( !ctx.recipient.male )::Bonjour Madame !::else::Bonjour Monsieur !::end::
3.  You work in these companies : ::ctx.recipient.companies.map( function( c ) return c.name ).join( ', ' )::
4.  Here are your companies :
5.  ::do var rand = Math.rand()::
6.  ::for( company in ctx.recipient.companies )::
7.  	::if( rand < .2 )::
8.  		::company.name.toLowerCase()::
9.  	::elseif(() rand > .7 )::
10.  		::company.name.toUpperCase()::
11.  	::else::
12.  		::company.name::
13.  	::end::
14.  ::end::
```
So you can catch errors like that :
```haxe
try{
	var parser	= new hscript.Parser();
	var ast 	= parser.parseString( tpl.out );
	var interp 	= new hscript.Interp();
	interp.variables.set( "ctx", ctx );
	interp.variables.set( "Math", Math );
	var ret		=  interp.execute( ast );
	trace( ret );
}catch( e : hscript.Expr.Error ){
	var lines	= s.split( "\n" );
	trace( "HScript parser error " + e + " : " + StringTools.trim( lines[ e.line - 1 ] ) );
	for( i in 0...lines.length ){
		trace( i + 1, lines[ i ] );
	}
}catch( e ){
	trace( "HScript interpreter : " + e.message );
}
```
And you will see `HScript parser error hscript:9: Unexpected token: ")" : ::elseif(() rand > .7 )::`

Note that hscript gives the line number starting from 1, so you have to decrement to get the array index of the template sources splitted by newlines `\n`

## Compile-time

I'll used tink_template until today. Tink_template is really a good lib, Juraj is really a good coder and I thank him for all his work but Tink has a lot of dependencies and I don't really like that, so I turned this little class that was first written to work on run-time, to work now on compile-time.

BTW, this class with hscript runs faster that tink_template 😲

You must add that to your build file : 
```
--macro ftk.format.Template.buildTemplates()
# And if you want to get template error position :
-D hscriptPos
```
Then the render function is the same as in tink_template, for example :
```haxe
@:template( "tpl/myTemplate.mtt" ) public function render();
```
The source file path is relative to the class file. Extension isn't important.

Note : the reported error position is a little buggy, I'll try to fix that when I'll have time.
