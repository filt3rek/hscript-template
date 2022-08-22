package ftk.format.template;

/**
 * @version 2.0.0
 * @author filt3rek
 */

class Tools{
	public static var stdClasses	= [ "Std", "Math", "Date", "StringTools", "DateTools", "Lambda", "haxe.ds.StringMap", "haxe.ds.IntMap", "haxe.ds.ObjectMap" ];

	/*
	*	This function will add and keep all the std classes to be available at run-time (when addStd is set at true in the Interp constructor)
	*/

	public static function addStd(){
#if macro
		for( cname in stdClasses ){
			haxe.macro.Compiler.addMetadata( "@:keep", cname );
		}
#end
	}
}