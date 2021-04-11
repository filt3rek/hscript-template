# hscript-template
Little run-time template system based on hscript

A little class that “generates” a “haxe source” which you can use with hscript to get a run-time template system.
It can be improved of course but I stop here for now I get all for my needs.
The synthax is almost the same as in tink_template and it supports expressions output, if, else, for statements and “do”.
I didn’t wrote any error handling because hscript does that.
This class could directly generate hscript AST expressions, but I’ve done that quickly, I have no time to look deeper into hscript for now.

Here is an example of a working template :
```
Hello "::ctx.recipient.name::", your main company is : ::ctx.recipient.companies[ 0 ].name::
::if( !ctx.recipient.male )::Bonjour Madame !::else::Bonjour Monsieur !::end::
You work in these companies : ::ctx.recipient.companies.map( function( c ) return c.name ).join( ', ' )::
Here are your companies :
::do var rand = Math.rand()::
::for( company in ctx.recipient.companies )::
	::if( rand < .5 )::
		::company.name::
	::else::
		None
	::end::
::end::
```

You can also customize the sign used to delimitate expressions and the keywords as if, else, for, end and do.
So now you can wrtie templates like that (like in the awful WINDEV :rofl: ) :
```
Hello "**ctx.recipient.name**", your main company is : **ctx.recipient.companies[ 0 ].name**
**si( !ctx.recipient.male )**Bonjour Madame !**sinon**Bonjour Monsieur !**fin**
You work in these companies : **ctx.recipient.companies.map( function( c ) return c.name ).join( ', ' )**
Here are your companies :
**pose var rand = Math.random()**
**boucle( company in ctx.recipient.companies )**
	**si( rand < .5 )**
		**company.name**
	**sinon**
		None
	**fin**
**fin**
```
And get a pretty output if you want debug maybe. So this is the result you get and give to eat to hscript : 
```haxe
var s	= "";
s	+= "Hello \"";
s	+= ctx.recipient.name;
s	+= "\", your main company is : ";
s	+= ctx.recipient.companies[ 0 ].name;
s	+= "
";
if( !ctx.recipient.male ){
	s	+= "Bonjour Madame !";
}else{
	s	+= "Bonjour Monsieur !";
}
s	+= "
You work in these companies : ";
s	+= ctx.recipient.companies.map( function( c ) return c.name ).join( ', ' );
s	+= "
Here are your companies :
";
var rand = Math.random();
s	+= "
";
for( company in ctx.recipient.companies ){
	s	+= "
	";
	if( rand < .5 ){
		s	+= "
		";
		s	+= company.name;
		s	+= "
	";
	}else{
		s	+= "
		None
	";
	}
	s	+= "
";
}
return s;
```
Here is a full example https://try.haxe.org/#34238fB1 :
```haxe
class Test {
	static function main() {
          var s = "Hello \"**ctx.recipient.name**\", your main company is : **ctx.recipient.companies[ 0 ].name**
      **si( !ctx.recipient.male )**Bonjour Madame !**sinon**Bonjour Monsieur !**fin**
      You work in these companies : **ctx.recipient.companies.map( function( c ) return c.name ).join( ', ' )**
      Here are your companies :
      **pose var rand = Math.random()**
      **boucle( company in ctx.recipient.companies )**
        **si( rand < .5 )**
          **company.name**
        **sinon**
          None
        **fin**
      **fin**";

          Template.PRETTY	= true;
          Template.SIGN	= "*";
          Template.DO	= "pose";
          Template.IF	= "si";
          Template.ELSE	= "sinon";
          Template.FOR	= "boucle";
          Template.END	= "fin";
          var tpl	= new Template();
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
