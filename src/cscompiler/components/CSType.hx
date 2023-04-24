package cscompiler.components;

#if (macro || cs_runtime)

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using reflaxe.helpers.ModuleTypeHelper;
using reflaxe.helpers.NameMetaHelper;

/**
	The component responsible for compiling Haxe
	types into C#.
**/
class CSType extends CSBase {
	/**
		Generates the C# type code given the Haxe `haxe.macro.Type`.

		TODO.
	**/
	public function compile(type: Type, pos: Position): Null<String> {
		return switch(type) {
			case TMono(refType): {
				final maybeType = refType.get();
				if(maybeType != null) {
					compile(maybeType, pos);
				} else {
					null;
				}
			}
			case TEnum(enumRef, params): {
				withTypeParams(enumRef.get().getNameOrNative(), params, pos);
			}
			case TInst(clsRef, params): {
				withTypeParams(compileClassName(clsRef.get()), params, pos);
			}
			case TType(_, _): {
				compile(#if macro Context.follow(type) #else type #end, pos);
			}
			case TFun(args, ref): {
				// TODO
				null;
			}
			case TAnonymous(anonRef): {
				// TODO
				null;
			}
			case TDynamic(maybeType): {
				// TODO
				null;
			}
			case TLazy(callback): {
				compile(callback(), pos);
			}
			case TAbstract(absRef, params): {
				var absType = absRef.get();
				var primitiveType = checkPrimitiveType(absType, params);

				if (primitiveType != null) {
					primitiveType;
				}
				else if (absType.name == "Null") {
					if (params != null && params.length > 0 && isValueType(params[0])) {
						compile(params[0], pos) + "?";
					}
					else {
						compile(params[0], pos);
					}
				}
				else {
					compile(#if macro Context.followWithAbstracts(type) #else type #end, pos);
				}
			}
		}
	}

	/**
		If the provided `TAbstract` info should generate a primitive type,
		this function compiles and returns the type name.

		Returns `null` if the abstract is not a primitive.
	**/
	function checkPrimitiveType(absType: AbstractType, params: Array<Type>): Null<String> {
		if(params.length > 0 || absType.pack.length > 0) {
			return null;
		}
		return switch(absType.name) {
			case "Void": "void";
			case "Int": "int";
			case "UInt": "uint";
			case "Float": "double";
			case "Bool": "bool";
			case _: null;
		}
	}

	/**
		Returns `true` if the given type is a **value type**.
		A **value type** is either a primitive type or a (C#) struct type.
	**/
	function isValueType(type: Type): Bool {
		return switch type {
			case TInst(t, params):
				// TODO classes with @:structAccess
				false;
			case TAbstract(absRef, params):
				final absType = absRef.get();
				final primitiveType = checkPrimitiveType(absType, params);
				if (primitiveType != null) {
					true;
				}
				else {
					#if macro isValueType(Context.followWithAbstracts(type)) #else false #end;
				}
			case _:
				false;
		}
	}

	/**
		Append type parameters to the compiled type.
	**/
	function withTypeParams(name: String, params: Array<Type>, pos: Position): String {
		return name + (params.length > 0 ? '<${params.map(p -> compile(p, pos)).join(", ")}>' : "");
	}

	/**
		Generate C# output for `ModuleType` used in an expression
		(i.e. for cast or static access).
	**/
	public function compileModuleExpression(moduleType: ModuleType): String {
		switch(moduleType) {
			case TClassDecl(clsRef): compileClassName(clsRef.get());
			case _:
		}
		return moduleType.getNameOrNative();
	}

	/**
		Get the name of the `ClassType` as it should appear in
		the C# output.
	**/
	public function compileClassName(classType: ClassType): String {
		return classType.getNameOrNative();
	}
}
#end
