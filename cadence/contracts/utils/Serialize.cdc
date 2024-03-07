/// This contract is a utility for serializing primitive types, arrays, and common metadata mapping formats to JSON
/// compatible strings. Also included are interfaces enabling custom serialization for structs and resources.
///
/// Special thanks to @austinkline for the idea and initial implementation.
///
access(all)
contract Serialize {

    /// Defines the interface for a struct that returns a serialized representation of itself
    ///
    access(all)
    struct interface SerializableStruct {
        access(all) fun serialize(): String
    }

    /// Defines the interface for a resource that returns a serialized representation of itself
    ///
    access(all)
    resource interface SerializableResource {
        access(all) fun serialize(): String
    }

    /// Method that returns a serialized representation of the given value or nil if the value is not serializable
    ///
    access(all)
    fun tryToString(_ value: AnyStruct): String? {
        // Call serialize on the value if available
        if value.getType().isSubtype(of: Type<{SerializableStruct}>()) {
            return (value as! {SerializableStruct}).serialize()
        }
        // Recursively serialize array & return
        if value.getType().isSubtype(of: Type<[AnyStruct]>()) {
            return self.arrayToString(value as! [AnyStruct])
        }
        // Recursively serialize map & return
        if value.getType().isSubtype(of: Type<{String: AnyStruct}>()) {
            return self.mapToString(value as! {String: AnyStruct})
        }
        // Handle primitive types & their respective optionals
        switch value.getType() {
            case Type<String>():
                return value as! String
            case Type<String?>():
                return value as? String ?? "nil"
            case Type<Character>():
                return (value as! Character).toString()
            case Type<Character?>():
                return (value as? Character)?.toString() ?? "nil"
            case Type<Bool>():
                return self.boolToString(value as! Bool)
            case Type<Bool?>():
                if value as? Bool == nil {
                    return "nil"
                }
                return self.boolToString(value as! Bool)
            case Type<Address>():
                return (value as! Address).toString()
            case Type<Address?>():
                return (value as? Address)?.toString() ?? "nil"
            case Type<Int8>():
                return (value as! Int8).toString()
            case Type<Int16>():
                return (value as! Int16).toString()
            case Type<Int32>():
                return (value as! Int32).toString()
            case Type<Int64>():
                return (value as! Int64).toString()
            case Type<Int128>():
                return (value as! Int128).toString()
            case Type<Int256>():
                return (value as! Int256).toString()
            case Type<Int>():
                return (value as! Int).toString()
            case Type<UInt8>():
                return (value as! UInt8).toString()
            case Type<UInt16>():
                return (value as! UInt16).toString()
            case Type<UInt32>():
                return (value as! UInt32).toString()
            case Type<UInt64>():
                return (value as! UInt64).toString()
            case Type<UInt128>():
                return (value as! UInt128).toString()
            case Type<UInt256>():
                return (value as! UInt256).toString()
            case Type<Word8>():
                return (value as! Word8).toString()
            case Type<Word16>():
                return (value as! Word16).toString()
            case Type<Word32>():
                return (value as! Word32).toString()
            case Type<Word64>():
                return (value as! Word64).toString()
            case Type<Word128>():
                return (value as! Word128).toString()
            case Type<Word256>():
                return (value as! Word256).toString()
            case Type<UFix64>():
                return (value as! UFix64).toString()
            default:
                return nil
        }
    }

    /// Method that returns a serialized representation of a provided boolean
    ///
    access(all)
    fun boolToString(_ value: Bool): String {
        return value ? "true" : "false"
    }

    /// Method that returns a serialized representation of the given array or nil if the value is not serializable
    ///
    access(all)
    fun arrayToString(_ arr: [AnyStruct]): String? {
        var serializedArr = "["
        for i, element in arr {
            let serializedElement = self.tryToString(element)
            if serializedElement == nil {
                return nil
            }
            serializedArr = serializedArr.concat("\"").concat(serializedElement!).concat("\"")
            if i < arr.length - 1 {
                serializedArr = serializedArr.concat(", ")
            }
        }
        serializedArr.concat("]")
        return serializedArr
    }

    /// Method that returns a serialized representation of the given String-indexed mapping or nil if the value is not
    /// serializable
    ///
    access(all)
    fun mapToString(_ map: {String: AnyStruct}): String? {
        var serializedMap = "{"
        for i, key in map.keys {
            let serializedValue = self.tryToString(map[key]!)
            if serializedValue == nil {
                return nil
            }
            serializedMap = serializedMap.concat("\"").concat(key).concat("\": \"").concat(serializedValue!).concat("\"}")
            if i < map.length - 1 {
                serializedMap = serializedMap.concat(", ")
            }
        }
        serializedMap.concat("}")
        return serializedMap
    }
}