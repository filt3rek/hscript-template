
# hscript-template
Little **run-time** and **compile-time** template system based on [hscript](https://github.com/HaxeFoundation/hscript)

This is a set of 2 simple classes :
- The *Parser* that "generates" a "hscript source" from a template source string.
- The *Template* that manages the "hscript source".

You get a full template system working both on compile-time and run-time.

The syntax is close to the `haxe.Template` or [tink_template](https://github.com/haxetink/tink_template) one and it supports **expressions output, if, else, elseif, switch, case, while, break, for** statements, **"do"** and **comments**.

- [Installation](https://github.com/filt3rek/hscript-template/blob/master/README.md#installation)
- [Usage](https://github.com/filt3rek/hscript-template/blob/master/README.md#usage)
- [Examples](https://github.com/filt3rek/hscript-template/blob/master/README.md#examples)
- [Delimiter and keywords customization](https://github.com/filt3rek/hscript-template/blob/master/README.md#delimiter-and-keywords-customization)
- [Error handling](https://github.com/filt3rek/hscript-template/blob/master/README.md#error-handling)
- [Code injection - Including templates in templates at run-time](https://github.com/filt3rek/hscript-template/blob/master/README.md#code-injection---including-templates-in-templates-at-run-time)
- [String interpolation](https://github.com/filt3rek/hscript-template/blob/master/README.md#string-interpolation)
- [How does it work ?](https://github.com/filt3rek/hscript-template/blob/master/README.md#how-does-it-work-)
- ["Do" statement](https://github.com/filt3rek/hscript-template/blob/master/README.md#do-statement)
- [Lasts words](https://github.com/filt3rek/hscript-template/blob/master/README.md#lasts-words)

## Installation
### Haxelib
You can use [Haxelib package manager](https://lib.haxe.org/) like that : `haxelib install hscript_template`.

Then, put that in your haxe project's build file :
```
-lib hscript_template
```
### Manual
Download the sources from Github.

Then, put that in your haxe project’s build file :
```
-p path/to/the/hscript_template/sources
-lib hscript
```

## Usage
### Compile-time *Template* class
All compile-time functions are statics of *Template* class
#### Automatic global build function (Init macro)
 - `buildTemplates( pathFilter = "", recursive = false, ?templateMeta : String )`

Add `--macro ftk.format.Template.buildTemplates()` into the *.hxml* build file.

The function will build all functions like that : `@:template( "my/path/to/templateFile" ) public function myFunction( arg1, arg2... );` in every types defined by `pathFilter` in your projet.

This function takes these optional arguments :
 - `pathFilter` : dot path to filter where the `@:build` will be added. `""` by default.
 - `recursive` : If `pathFilter` is the empty String `""` it matches everything (if `recursive = true`) or only top-level types (if `recursive = false`). `false` by default.
 - `templateMeta` : The meta that will be searched for building. `:template` by default.

#### Automatic per-type build function (Build macro)
 - `build()`

Add `@:build( ftk.format.template.Template.build() )` at the type where you want to proceed all `@:template` functions.

This function will build all functions like that : `@:template( "my/path/to/templateFile" ) public function myFunction( arg1, arg2... );` in the wanted type.

#### Manual function that builds the template from a file (Expr macro)

 - `buildFromFile( path : String, ?isFullPath : Bool )`
```
public function myFunction( arg1, arg2... ){
  var x = "foo";
  ...
  ftk.format.template.Template.buildFromFile( "my/path/to/templateFile" );
}
```

This function takes these arguments :
 - `path` : path to the file that contains the template's source.
 - `?isFullPath` : relative to the class (false) or to the project (true). false by default

#### Manual function that builds the template from a string (Expr macro)
- `buildFromString( content : String, ?path : String, ?isFullPath : Bool )`
```
public function myFunction( arg1, arg2... ){
  var x = "foo";
  ...
  ftk.format.template.Template.buildFromString( "::x:: is not bar" ); // foo is not bar
}
```
#### Compilation directives
 - `-D hscriptPos` to report error line related to hscript macro exprs generator.
 - `-D hscript_template_macro_pos` to report error line related to generated expressions.

#### Notes 
*With the automatic build, the source file path is relative to the class file.*

*With manual you can specify if it's relative to the class or not by adjusting the `isFullPath` argument. Extension isn't important.*

*You can also specify another template meta that will be used to detect template functions to generate. By default `@:template` is used but if you want to use `cheese` just do that* :
``` 
--macro ftk.format.template.Template.buildTemplates( "", true,":cheese" )
```
So you'll have that as templates functions :
```
@:cheese( "my/path/to/templateFile" ) public function render( arg1, arg2... );
```
### Run-time *Parser* class
Empty constructor and a single parse instance's function.

These variables are customizables, this way we can have custom keywords (see examples) :
- SIGN = ":"
- COMMENT = "*"
- IF = "if"
- ELSE = "else"
- ELSEIF = "elseif"
- FOR = "for"
- WHILE = "while"
- BREAK = "break"
- SWITCH = "switch"
- CASE = "case"
- END = "end"
- DO = "do"
#### Main function that parse a template's source into hscript source
- `parse( str : String )`

This function takes this argument :
- `str` : Template's source

### Run-time *Template* class

#### Constructor :
- `new( runtimePos = true, addStd = false )`

This function takes these arguments :
 - `?runtimePos` : If set to true, it will manage source code if errors occurs, especially when using inclusions. true by dafault
 - `?addStd` : If set to true, adds some standard haxe classes (Std, Math, Date, StringTools...)

#### Main function that generates a template
- `execute( hscriptSource : String, ?ctx : {}, isInclusion = false )`

This function takes these arguments :
 - `hscriptSource` : hscript source code generated by template's Parser output.
 - `?ctx` : Set of fields to include in hscript context
 - `?isInclusion` : Used internally.

#### Helper function that "safetly" includes a template into another template (injections)
- `include( hscriptSource : String )`

This function takes this argument :
 - `hscriptSource` : hscript source code generated by template's Parser output.

#### Compilation directives
 - `-D hscriptPos` to report error line related to hscript macro exprs generator.

## Examples
Here is an example of working template source : 
```
Hello "::recipient.name::", your main company is : ::recipient.companies[ 0 ].name::
::if( !recipient.male )::Bonjour Madame !::else::Bonjour Monsieur !::end::
You work in these companies : ::recipient.companies.map( function( c ) return c.name ).join( ', ' )::
Here are your companies :
::do var rand = Math.random()::
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
Here is the code that will generate the template from this source :
```
var parser 	= new ftk.format.template.Parser();
var output	= parser.parse( s );	// s is the template source above
trace( output );
var ctx = {
	recipient	: {
		name		: "Mrs. Annie Cordy",
		male		: false,
		companies	: [{ name : "Company 1" }, { name : "Company 2" }]
	}
}

var tpl	= new ftk.format.template.Template( false, true );	// runTimePos = false, addStd = true
trace( tpl.execute( output, ctx ) );
```
So first we get the output from the parser : 
```
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
And we give it to eat to the *Template*'s `execute` function and we get :
```
Hello "Mrs. Annie Cordy", your main company is : Company 1
Bonjour Madame !
You work in these companies : Company 1, Company 2
Here are your companies :
	Company 1
	Company 2
```
## Delimiter and keywords customization
We can also customize the *sign* used to delimitate expressions and the *keywords*.
```
var parser 			= new Parser();
	parser.SIGN 	= "*";
	parser.DO 		= "pose";
	parser.IF 		= "si";
	parser.ELSEIF 	= "ou_si";
	parser.ELSE 	= "sinon";
	parser.FOR 		= "boucle";
	parser.END 		= "fin";
```
This way we can write templates like that (like in the awful WINDEV-FR :rofl: ) :
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
Here is a full example of the *Parser*'s output : https://try.haxe.org/#0682baBD
## Error handling

For example if the template has an error like that (line 9) :
```
1.  Hello "::recipient.name::", your main company is : ::recipient.companies[ 0 ].name::
2.  ::if( !recipient.male )::Bonjour Madame !::else::Bonjour Monsieur !::end::
3.  You work in these companies : ::recipient.companies.map( function( c ) return c.name ).join( ', ' )::
4.  Here are your companies :
5.  ::do var rand = Math.random()::
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
```
try{
	return tpl.execute( output, ctx );
}catch( e : ftk.format.template.Template.TemplateError ){
	trace( e );
}
```

You will see `hscript:9: Unexpected token: ")" : }else if(() rand > .7 ){`

**Note** : *You have to add `-D hscriptPos` to your build file in order to get error position and set `runtimePos`to true in the Template's constructor*

As you can see, the native TemplateError gives the piece of hscript source code and not the one from the template used.

In order to get your template's source code, you'll have to split your template by `\n` and get the right array index -1.

The line number is preserved and is the same between both the template and hscript source's code.

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

## Code injection - Including templates in templates at run-time

There is a **special function** `__hscriptSource__` added automatically into context that permits to inject haxe code at the place where it's called.

This way you can “interact” with all the variables of the context, the ones that was created at run-time (by your source code) and even with the `__s__` global var that is the string output of your template.

So you can easily **include** another parsed template into this `__s__` at this place like that :

```
var a	= [];
a[ 0 ]	= '::do up = function( s ){ return s.toUpperCase(); }::';
a[ 1 ]	= '::include( 0 )::Hello ::up( "filt3rek" ):: !';
a[ 2 ]	= '::include( 0 )::Goodbye ::up( "filt3rek" ):: !';

var tpl	= new ftk.format.template.Template();
var p	= new ftk.format.template.Parser();

var ctx	= {
	include	: function( ind : Int ){
		var ret	= tpl.execute( '__hscriptSource__( \'__s__+=${ escapeQuotes( p.parse( a[ ind ] ) ) };\' )' );	// (1)
		// OR using a template's helper function :
		var ret	= tpl.include( p.parse( a[ ind ] ) );								// (2)
		return ret;
	}
}
var source	= '::include( 0 )::::include( 1 ):: It\'s a test ! ::include( 2 )::';
var source2	= p.parse( source );
trace( tpl.execute( source2, ctx ) );
}
```
That gives you : `Hello FILT3REK ! It's a test ! Goodbye FILT3REK !`

As you can see, I added a custom `include` function into my cutom context in order to make it easier than directly calling the `__hscriptSource__` function.

Then, here I call array here, but for my projects, I often load another template at runtime and inject it's content...

### 2 methods here :

 1. Manual injection.
You have to escape quotes by your own, if needed, when you directly call the `__hscriptSource__` context's function, what can be done using another helper function `escapeQuotes` on Template's class :
```
public function escapeQuotes( s : String ){
	return s.split( '"' ).join( '\\"' ).split( "'" ).join( "\\'" );
}
```
 2. There also is a `include` **helper function** on *Template*'s class that do "safetly" inclusion for you (i.e. by escaping quotes)

But you can also use the helper function `escapeQuotes` on *Template*'s class


## String interpolation

Because by default *hscript* doesn't manage string interpolation even in macro mode, *Template* class does it.

But if you have a `$` var inside your template source, (i.e. an inlined JS script that uses the `$` sign, you can escape it using `$$`

## How does it work ?

All the template's source is turned into a **string concatenation**.

The basic text (or html) is concatened into text and all the expressions are just evaluated and then concatened into this same string, as you can see in the examples above (*Parser*'s output).

## "Do" statement

With the "do" statement, you can do everything you want.

Since all the expressions are just evaluated, you can write **any Haxe valid expression** like let **variables**, **functions** and everything that can be evaluated at the place the template is rendered.

On compile-time, the template is rendered so you get a string concatenation that is "injected" in the body of the function.

This function just returns this string with the basic text and all the evaluated expressions...

## Lasts words
*I was mainly inspired by the [tink_template](https://github.com/haxetink/tink_template)'s process of code injection in body function. Thanks Juraj for this wonderful lib that I used for many years !*

This little lib is simplier to use than the explanation with my wonderful english in this Readme file to read and understand :rofl:

You can take a look at [tink_template](https://github.com/haxetink/tink_template) Readme file if you haven't understood something here because the approach is very similar.

