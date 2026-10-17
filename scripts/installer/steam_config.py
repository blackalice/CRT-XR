"""Strict offline Steam KeyValues readers. Unknown syntax fails before any writes."""
import re
import struct


def load_binary(data):
    offset = 0

    def take(n):
        nonlocal offset
        if offset+n > len(data):
            raise ValueError('Truncated Steam shortcuts file')
        value=data[offset:offset+n]; offset+=n
        return value

    def string():
        nonlocal offset
        end=data.find(b'\0',offset)
        if end<0: raise ValueError('Unterminated Steam string')
        return take(end-offset+1)[:-1].decode('utf-8','surrogateescape')

    def tree():
        result={}
        while True:
            kind=take(1)[0]
            if kind==8: return result
            key=string()
            if key in result: raise ValueError('Duplicate Steam shortcut key')
            if kind==0: value=tree()
            elif kind==1: value=string()
            elif kind in (2,3,4,6): value=take(4)
            elif kind in (7,10): value=take(8)
            else: raise ValueError('Unsupported Steam shortcut value type: '+str(kind))
            result[key]=(kind,value)
    result=tree()
    if offset!=len(data): raise ValueError('Unexpected trailing Steam shortcut data')
    return result


def dump_binary(tree):
    def string(value): return value.encode('utf-8','surrogateescape')+b'\0'
    output=b''
    for key,(kind,value) in tree.items():
        output+=bytes([kind])+string(key)
        output+=dump_binary(value) if kind==0 else string(value) if kind==1 else value
    return output+b'\x08'


def integer(value): return (2,struct.pack('<I',value & 0xffffffff))


def load_text(text):
    tokens=re.findall(r'"(?:\\.|[^"\\])*"|[{}]|//[^\n]*|[^\s{}]+',text)
    tokens=[t for t in tokens if not t.startswith('//')]
    at=0
    def quoted(token):
        if not token.startswith('"') or not token.endswith('"'): raise ValueError('Unsupported Steam text syntax')
        return re.sub(r'\\(["\\])',r'\1',token[1:-1])
    def tree(nested=False):
        nonlocal at
        result={}
        while at<len(tokens):
            if tokens[at]=='}':
                if not nested: raise ValueError('Unexpected Steam closing brace')
                at+=1; return result
            key=quoted(tokens[at]); at+=1
            if at>=len(tokens): raise ValueError('Missing Steam value')
            if key in result: raise ValueError('Duplicate Steam configuration key')
            token=tokens[at]; at+=1
            result[key]=tree(True) if token=='{' else quoted(token)
        if nested: raise ValueError('Unclosed Steam configuration object')
        return result
    return tree()


def dump_text(tree,depth=0):
    def quote(value): return '"'+value.replace('\\','\\\\').replace('"','\\"')+'"'
    result=''; indent='\t'*depth
    for key,value in tree.items():
        result+=indent+quote(key)
        if isinstance(value,dict): result+='\n'+indent+'{\n'+dump_text(value,depth+1)+indent+'}\n'
        else: result+='\t\t'+quote(value)+'\n'
    return result


def branch(tree,path):
    for key in path:
        actual=next((k for k in tree if k.lower()==key.lower()),key)
        tree=tree.setdefault(actual,{})
        if not isinstance(tree,dict): raise ValueError('Unexpected Steam configuration structure')
    return tree
