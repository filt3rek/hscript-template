# hscript-template
Little **run-time** and **compile-time** template system based on https://github.com/HaxeFoundation/hscript

This is a <del>single simple class</del> set of 2 simple classes that “generate” a “haxe source” which you can use with *hscript* to get a template system working like https://github.com/haxetink/tink_template.

The synthax is almost the same as in *tink_template* and it supports **expressions output, if, else, elseif, switch, case, while, break, for** statements, **“do”** and **comments**.

**It works the same way on run-time and compile-time.**

The main Parser's function `parse` just parses a string (that can come from a file) and converts it to a **string concatenation**. Then you can give the result to *hscript* manually that will interpret it or use the `execute` function that will do the job automatically.

The Template's function `execute`, available for run-time, will do the link with *hscript* automatically and give you the result or throw an `TemplateError` with the **line number**, source and the native hscript error that occured.

For compile-time I added another helper macro functions `buildFromFile`, `buildFromString` and `buildTemplates`. The 2 first that you can use manually, the second that automatically generates all templates in your project. Take a look at the [**Compile-Time**](#compile-time)  paragraph.

## Installation
### Haxelib
You can use [Haxelib package manager](https://lib.haxe.org/) like that : `haxelib install hscript_template`.
Then, put that in your haxe build file :
```
-lib hscript
-lib hscript_template
```
You can also add expra params in order to get run-time and/or compile-time errors reporting.
Then you can use it in "automatic" or "manual" mode for compile-time. Take a look at [**Compile-Time**](#compile-time)  paragraph.
### From sources
Download the sources. Put it to your project. Build and take a beer.

## Example of a working template :
```
Hello "::recipient.name::", your main company is : ::recipient.companies[ 0 ].name::
::if( !recipient.male )::Bonjour Madame !::else::Bonjour Monsieur !::end::
You work in these companies : ::recipient.companies.map( function( c ) return c.name ).join( ', ' )::
Here are your companies :
::do var rand = Math.rand()::
::for( company in recipient.companies )::
	::if( rand < .2 )::
		::company.name.toLowerCase()::
	::elseif( rand > .7 )::
		::company.name.toUpperCase()::
	::else::
		::company.name::
	::end::
::end::
```
You can also customize the sign used to delimitate expressions and the keywords as if, else, for, end, switch, case and do.
So now you can write templates like that (like in the awful WINDEV-FR :rofl: ) :
```
Hello "**recipient.name**", your main company is : **recipient.companies[ 0 ].name**
**si( !recipient.male )**Bonjour Madame !**sinon**Bonjour Monsieur !**fin**
You work in these companies : **recipient.companies.map( function( c ) return c.name ).join( ', ' )**
Here are your companies :
**pose var rand = Math.random()**
**boucle( company in recipient.companies )**
	**si( rand < .2 )**
		**company.name.toLowerCase()**
	**ou_si( rand > .7 )**
		**company.name.toUpperCase()**
	**sinon**
		**company.name**
	**fin**
**fin**
```
This is the result you get and give to eat to *hscript* : 
```haxe
var __s__="";__s__+="Hello \"";__s__+=recipient.name;__s__+="\", your main company is : ";__s__+=recipient.companies[ 0 ].name;__s__+="
      ";if(( !recipient.male )){__s__+="Bonjour Madame !";}else{__s__+="Bonjour Monsieur !";}__s__+="
      You work in these companies : ";__s__+=recipient.companies.map( function( c ) return c.name ).join( ', ' );__s__+="
      Here are your companies :
      ";var rand = Math.random();__s__+="
      ";for( company in recipient.companies ){__s__+="
        ";if(( rand < .2 )){__s__+="
		";__s__+=company.name.toLowerCase();__s__+="
	";}else if(( rand > .7 )){__s__+="
		";__s__+=company.name.toUpperCase();__s__+="
	";}else{__s__+="
		";__s__+=company.name;__s__+="
	";}__s__+="
      ";}__s__+="";return __s__;
```
*At the begining I've written a "pretty" mode to output with indents and newlines but I don't see the need at the end because it's to be given to eat to hscript, not to masturbate in front of it, so I removed that.*

## Run-time

Here is a full example https://try.haxe.org/#5Bb026db :
```haxe
class Test {
	static function main() {
		var s = "Hello \"**recipient.name**\", your main company is : **recipient.companies[ 0 ].name**
      **si( !recipient.male )**Bonjour Madame !**sinon**Bonjour Monsieur !**fin**
      You work in these companies : **recipient.companies.map( function( c ) return c.name ).join( ', ' )**
      Here are your companies :
      **pose var rand = Math.random()**
      **boucle( company in recipient.companies )**
        **si( rand < .2 )**
		**company.name.toLowerCase()**
	**ou_si( rand > .7 )**
		**company.name.toUpperCase()**
	**sinon**
		**company.name**
	**fin**
      **fin**";

		var parser 			= new Parser();
		/*** This part is not needed, it's here just to show that you can change the keywords...*/
			parser.SIGN 	= "*";
			parser.DO 		= "pose";
			parser.IF 		= "si";
			parser.ELSEIF 	= "ou_si";
			parser.ELSE 	= "sinon";
			parser.FOR 		= "boucle";
			parser.END 		= "fin";
		/*** */
   		var output	= parser.parse( s );
		trace( output );

		var ctx = {
			recipient	: {
				name		: "Mrs. Annie Cordy",
				male		: false,
				companies	: [{ name : "Company 1" }, { name : "Company 2" }]
			}
		}

		/*var tpl	= new Template();
    		tpl.execute( output, ctx );*/
	}
}
```
### Error handling

For example if the template has an error like that (line 9) :
```
1.  Hello "::recipient.name::", your main company is : ::recipient.companies[ 0 ].name::
2.  ::if( !recipient.male )::Bonjour Madame !::else::Bonjour Monsieur !::end::
3.  You work in these companies : ::recipient.companies.map( function( c ) return c.name ).join( ', ' )::
4.  Here are your companies :
5.  ::do var rand = Math.rand()::
6.  ::for( company in recipient.companies )::
7.  	::if( rand < .2 )::
8.  		::company.name.toLowerCase()::
9.  	::elseif(() rand > .7 )::
10.  		::company.name.toUpperCase()::
11.  	::else::
12.  		::company.name::
13.  	::end::
14.  ::end::
```

With this code :
```haxe
try{
	return tpl.execute( output, ctx );
}catch( e : ftk.format.template.Template.TemplateError ){
	trace( e );
}
```

You will see `hscript:9: Unexpected token: ")" : }else if(() rand > .7 ){`

**Note** : *You have to add `-D hscriptPos` to your build file in order to get error position*

As you can see, the native TemplateError gives the piece of hscript source code and not the one from the template used. In order to get your template's source code, you'll have to split your template by `\n` and get the right array index -1. The line number is preserved and is the same between both the template and hscript source's code.

So something like that should do the job :
```haxe
try{
	return tpl.execute( output, ctx );
}catch( e : ftk.format.template.Template.TemplateError ){
	var lines	= output.split( "\n" );
	trace( lines[ e.native.line - 1 ] );
}
```
Will give you : `::elseif(() rand > .7 )::` insted of `}else if(() rand > .7 ){` 

## Code injection - Including templates in templates on run-time

There is a **special function** `__inject__` added automatically into context that permits to inject haxe code at the place where it's called.

This way you can “interact” with all the variables of the context, the ones that was created at run-time (by your source code) and even with the `__s__` global var that is the string output of your template.

So you can easily **include** another parsed template into this `__s__` at this place like that :

```haxe
var a	= [];
a[ 0 ]	= '::do up = function( s ){ return s.toUpperCase(); }::';
a[ 1 ]	= '::include( 0 )::Hello ::up( "filt3rek" ):: !';
a[ 2 ]	= '::include( 0 )::Goodbye ::up( "filt3rek" ):: !';

var tpl	= new ftk.format.template.Template();
var p	= new ftk.format.template.Parser();

var ctx	= {
	include	: function( ind : Int ){
		var ret	= tpl.execute( '__include__( \'__s__+=${ p.parse( a[ ind ] ) };\' )' );
		return ret;
	}
}
var source	= '::include( 0 )::::include( 1 ):: It\'s a test ! ::include( 2 )::';
var source2	= p.parse( source );
trace( tpl.execute( source2, ctx ) );
}
```

That gives you : `Hello FILT3REK ! It's a test ! Goodbye FILT3REK !`

As you can see, I added a custom `include` function into my cutom context in order to make it easier and in fact at the place I call array here, I use to load another template at runtime and inject it's content...

**Note** : *You have to escape quotes by your own, if needed, what can be done like that :*

```haxe
function escapeQuotes( s : String ){
	return s.split( '"' ).join( '\\"' ).split( "'" ).join( "\\'" );
}
```

## Compile-time

The easiest way to use it for compile-time is to add this to your build file :
```
--macro ftk.format.Template.buildTemplates()
# And if you want to get template error position :
-D hscriptPos
-D templatePos
```
Then the render function is the same as in *tink_template*, for example :
```haxe
@:template( "my/path/to/templateFile" ) public function render( arg1, arg2... );
```
**Note** : *With the automatic build, the source file path is relative to the class file. With manual you can specify if it's relative to the class or not by adjusting the `isFullPath` argument.
Extension isn't important. You can also specify another template meta that will be used to detect template functions to generate. By default `@:template()` is used but if you want to use `cheese` just do that* :
``` 
--macro ftk.format.Template.buildTemplates( null, "cheese" )
```
So you'll have that as templates functions :
```
@:cheese( "my/path/to/templateFile" ) public function render( arg1, arg2... );
```

It will just parse your template file, convert it to a string concatenation, transform it into Haxe macro expressions and populate the body function with these macro expressions. So the result is a function that you can call anywhere and get the string concatenation.

You can also use the macro `buildFromFile` function manually like that :
```haxe
public function render( arg1, arg2... ){
	var x	= "foo";
	...
	ftk.format.Template.buildFromFile( "my/path/to/templateFile" );
}
```
Same for the `buildFromString` function except that you directly put the string to be treated as template.
So you can mix some manipulations and the resulting template.

**Note** : *Don't forget to add that in your build file in order to get the right error's line* :
```
-D hscriptPos
-D templatePos
```

### String interpolation

Because by default *hscript* doesn't manage string interpolation even in macro mode, another work is needed to get string interpolation working (only in compile-time). For that by default the token `$` is used. But if you use the `$` sign somewhere in your template that has nothing to do with string interpolation, i.e. some javascript scripts use the `$` sign as variables names, you have to specify another token for the real string interpolation token like that :
```
--macro ftk.format.Template.buildTemplates( "$$" )
```
And this will be correctly interpolated:
```haxe
::do var n = 4::
::"foo$$n"::
```
Here I use `$$` but you can specify what you want.

**Note** : You don't need to use single quote `'`. All the strings that has `$$` inside it will be interpolated. That is in fact why you need to specify antoher string interpolation token if inside your template there is i.e. a javascript that use the `$` sign in the variable's name...

## How does it work ?

All the template is turned into a **string concatenation**. The basic text (or html) is concatened into text and all the expressions are just evaluated and then concatened into this same string, as you can see in the examples above.

### "Do" statement

With the "do" statement, you can do everything you want.
Since all the expressions are just evaluated, you can write **any Haxe valid expression** like let **variables**, **functions** and everything that can be evaluated at the place the template is rendered.

On compile-time, the template is rendered so you get a string concatenation that is "injected" in the body of the function. This function just returns this string with the basic text and all the evaluated expressions...

## Last word

This little lib is simplier to use than the explanation with my wonderful english in this Readme file to read and understand :rofl:
