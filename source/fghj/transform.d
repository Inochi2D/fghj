/++
Mutable FGHJ data structure.
The representation can be used to compute a difference between JSON object-trees.

Copyright: Tamedia Digital, 2016

Authors: Ilya Yaroshenko

License: BSL-1.0
+/
module fghj.transform;

import fghj.fghj;
import fghj.serialization;
import std.exception: enforce;

/++
Object-tree structure for mutable Fghj representation.

`FghjNode` can be used to construct and manipulate JSON objects.
Each `FghjNode` can represent either a dynamic JSON object (associative array of `FghjNode` nodes) or a FGHJ JSON value.
JSON arrays can be represented only as JSON values.
+/
struct FghjNode
{
    /++
    Children nodes.
    +/
    FghjNode[const(char)[]] children;
    /++
    Leaf data.
    +/
    Fghj data;

pure:

    /++
    Returns `true` if the node is leaf.
    +/
    bool isLeaf() const @safe pure nothrow @nogc
    {
        return cast(bool) data.data.length;
    }

    /++
    Construct `FghjNode` recursively.
    +/
    this(Fghj data)
    {
        if(data.kind == Fghj.Kind.object)
        {
            foreach(kv; data.byKeyValue)
            {
                children[kv.key] = FghjNode(kv.value);
            }
        }
        else
        {
            this.data = data;
            enforce(isLeaf);
        }
    }

    ///
    ref FghjNode opIndex(scope const(char)[][] keys...) scope return
    {
        if(keys.length == 0)
            return this;
        auto ret = this;
        for(;;)
        {
            auto ptr = keys[0] in ret.children;
            enforce(ptr, "FghjNode.opIndex: keys do not exist");
            keys = keys[1 .. $];
            if(keys.length == 0)
                return *ptr;
            ret = *ptr;
        }
    }

    ///
    unittest
    {
        import fghj;
        auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
        auto root = FghjNode(text.parseJson);
        assert(root["inner", "a"].data == `true`.parseJson);
    }

    ///
    void opIndexAssign(FghjNode value, scope const(char)[][] keys...)
    {
        auto root = &this;
        foreach(key; keys)
        {
            L:
            auto ptr = key in root.children;
            if(ptr)
            {
                enforce(ptr, "FghjNode.opIndex: keys do not exist");
                keys = keys[1 .. $];
                root = ptr;
            }
            else
            {
                root.children[keys[0]] = FghjNode.init;
                goto L;
            }
        }
        *root = value;
    }

    ///
    unittest
    {
        import fghj;
        auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
        auto root = FghjNode(text.parseJson);
        auto value = FghjNode(`true`.parseJson);
        root["inner", "g", "u"] = value;
        assert(root["inner", "g", "u"].data == true);
    }

    /++
    Params:
        value = default value
        keys = list of keys
    Returns: `[keys]` if any and `value` othervise.
    +/
    FghjNode get(FghjNode value, in char[][] keys...)
    {
        auto ret = this;
        foreach(key; keys)
            if(auto ptr = key in ret.children)
                ret = *ptr;
            else
            {
                ret = value;
                break;
            }
        return ret;
    }

    ///
    unittest
    {
        import fghj;
        auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
        auto root = FghjNode(text.parseJson);
        auto value = FghjNode(`false`.parseJson);
        assert(root.get(value, "inner", "a").data == true);
        assert(root.get(value, "inner", "f").data == false);
    }

    /// Serialization primitive
    void serialize(ref FghjSerializer serializer)
    {
        if(isLeaf)
        {
            serializer.app.put(cast(const(char)[])data.data);
            return;
        }
        auto state = serializer.structBegin;
        foreach(key, ref value; children)
        {
            serializer.putKey(key);
            value.serialize(serializer);
        }
        serializer.structEnd(state);
    }

    ///
    Fghj opCast(T : Fghj)()
    {
        return serializeToFghj(this);
    }

    ///
    unittest
    {
        import fghj;
        auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
        auto root = FghjNode(text.parseJson);
        import std.stdio;
        Fghj flat = cast(Fghj) root;
        assert(flat["inner", "a"] == true);
    }

    ///
    bool opEquals(in FghjNode rhs) const @safe pure nothrow @nogc
    {
        if(isLeaf)
            if(rhs.isLeaf)
                return data == rhs.data;
            else
                return false;
        else
            if(rhs.isLeaf)
                return false;
            else
                return children == rhs.children;
    }

    ///
    unittest
    {
        import fghj;
        auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
        auto root1 = FghjNode(text.parseJson);
        auto root2= FghjNode(text.parseJson);
        assert(root1 == root2);
        assert(root1["inner"].children.remove("b"));
        assert(root1 != root2);
    }

    /// Adds data to the object-tree recursively.
    void add(Fghj data)
    {
        if(data.kind == Fghj.Kind.object)
        {
            this.data = Fghj.init;
            foreach(kv; data.byKeyValue)
            {
                if(auto nodePtr = kv.key in children)
                {
                    nodePtr.add(kv.value);
                }
                else
                {
                    children[kv.key] = FghjNode(kv.value);
                }
            }
        }
        else
        {
            this.data = data;
            children = null;
        }
    }

    ///
    unittest
    {
        import fghj;
        auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
        auto addition = `{"do":"re","inner":{"a":false,"u":2}}`;
        auto root = FghjNode(text.parseJson);
        root.add(addition.parseJson);
        auto result = `{"do":"re","foo":"bar","inner":{"a":false,"u":2,"b":false,"c":"32323","d":null,"e":{}}}`;
        assert(root == FghjNode(result.parseJson));
    }

    /// Removes keys from the object-tree recursively.
    void remove(Fghj data)
    {
        enforce(children, "FghjNode.remove: fghj data must be a sub-tree");
        foreach(kv; data.byKeyValue)
        {
            if(kv.value.kind == Fghj.Kind.object)
            {
                if(auto nodePtr = kv.key in children)
                {
                    nodePtr.remove(kv.value);
                }
            }
            else
            {
                children.remove(kv.key);
            }
        }
    }

    ///
    unittest
    {
        import fghj;
        auto text = `{"foo":"bar","inner":{"a":true,"b":false,"c":"32323","d":null,"e":{}}}`;
        auto rem = `{"do":null,"foo":null,"inner":{"c":null,"e":null}}`;
        auto root = FghjNode(text.parseJson);
        root.remove(rem.parseJson);
        auto result = `{"inner":{"a":true,"b":false,"d":null}}`;
        assert(root == FghjNode(result.parseJson));
    }

    private void removedImpl(ref FghjSerializer serializer, FghjNode node)
    {
        import std.exception : enforce;
        enforce(!isLeaf);
        enforce(!node.isLeaf);
        auto state = serializer.structBegin;
        foreach(key, ref value; children)
        {
            auto nodePtr = key in node.children;
            if(nodePtr && *nodePtr == value)
                continue;
            serializer.putKey(key);
            if(nodePtr && !nodePtr.isLeaf && !value.isLeaf)
                value.removedImpl(serializer, *nodePtr);
            else
                serializer.putValue(null);
         }
        serializer.structEnd(state);
    }

    /++
    Returns the subset of the object-tree which is not represented in `node`.
    If a leaf is represented but has a different value then it will be included
    in the return value.
    Returned value has FGHJ format and its leaves are set to `null`.
    +/
    Fghj removed(FghjNode node)
    {
        auto serializer = fghjSerializer();
        removedImpl(serializer, node);
        serializer.flush;
        return serializer.app.result;
    }

    ///
    unittest
    {
        import fghj;
        auto text1 = `{"inner":{"a":true,"b":false,"d":null}}`;
        auto text2 = `{"foo":"bar","inner":{"a":false,"b":false,"c":"32323","d":null,"e":{}}}`;
        auto node1 = FghjNode(text1.parseJson);
        auto node2 = FghjNode(text2.parseJson);
        auto diff = FghjNode(node2.removed(node1));
        assert(diff == FghjNode(`{"foo":null,"inner":{"a":null,"c":null,"e":null}}`.parseJson));
    }

    void addedImpl(ref FghjSerializer serializer, FghjNode node)
    {
        import std.exception : enforce;
        enforce(!isLeaf);
        enforce(!node.isLeaf);
        auto state = serializer.structBegin;
        foreach(key, ref value; node.children)
        {
            auto nodePtr = key in children;
            if(nodePtr && *nodePtr == value)
                continue;
            serializer.putKey(key);
            if(nodePtr && !nodePtr.isLeaf && !value.isLeaf)
                nodePtr.addedImpl(serializer, value);
            else
                value.serialize(serializer);
         }
        serializer.structEnd(state);
    }

    /++
    Returns the subset of the node which is not represented in the object-tree.
    If a leaf is represented but has a different value then it will be included
    in the return value.
    Returned value has FGHJ format.
    +/
    Fghj added(FghjNode node)
    {
        auto serializer = fghjSerializer();
        addedImpl(serializer, node);
        serializer.flush;
        return serializer.app.result;
    }

    ///
    unittest
    {
        import fghj;
        auto text1 = `{"foo":"bar","inner":{"a":false,"b":false,"c":"32323","d":null,"e":{}}}`;
        auto text2 = `{"inner":{"a":true,"b":false,"d":null}}`;
        auto node1 = FghjNode(text1.parseJson);
        auto node2 = FghjNode(text2.parseJson);
        auto diff = FghjNode(node2.added(node1));
        assert(diff == FghjNode(`{"foo":"bar","inner":{"a":false,"c":"32323","e":{}}}`.parseJson));
    }
}
