# hscript-template
Little run-time template system based on hscript

A little class that “generates” a “haxe source” which you can use with hscript to get a run-time template system.
It can be improved of course but I stop here for now I get all for my needs.
The synthax is almost the same as in tink_template and it supports expressions output, if, else, elseif, for statements and “do”.
I didn’t wrote any error handling because hscript does that but you can see how catch errors at the end of this document.
This class could directly generate hscript AST expressions, but I’ve done that quickly, I have no time to look deeper into hscript for now.

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
Hello "::ctx.recipient.name::", your main company is : ::ctx.recipient.companies[ 0 ].name::
::if( !ctx.recipient.male )::Bonjour Madame !::else::Bonjour Monsieur !::end::
You work in these companies : ::ctx.recipient.companies.map( function( c ) return c.name ).join( ', ' )::
Here are your companies :
::do var rand = Math.rand()::
::for( company in ctx.recipient.companies )::
	::if( rand < .2 )::
		::company.name.toLowerCase()::
	::elseif(() rand > .7 )::
		::company.name.toUpperCase()::
	::else::
		::company.name::
	::end::
::end::
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
