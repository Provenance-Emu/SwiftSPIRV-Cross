// Copyright (c) 2020 Stuart Carnie
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import CSPIRVCross
import Foundation

public protocol Compiler {
    associatedtype OptionsType: CompilerOptions
    
    var entryPoints: [SPVEntryPoint] { get }
    
    func makeOptions() -> OptionsType
    func makeResources() -> SPVResources
    func compile() throws -> String
    func compile(options: OptionsType) throws -> String
    func getType(id: SPVTypeID) -> SPVType?
    func getVariable(resource: SPVReflectedResource) -> SPVVariable?
}

public protocol CompilerOptions {}

protocol InternalCompiler: Compiler where Self.OptionsType: InternalCompilerOptions {
    var compiler: SPVCompiler { get }
}

protocol InternalCompilerOptions: CompilerOptions {
    var options: SPVCompilerOptions { get }
    init(options: SPVCompilerOptions)
    
    func apply(to compiler: SPVCompiler)
}

@frozen
public struct SPVEntryPoint {
    let data: __spvc_entry_point
    
    public var executionModel: SPVExecutionModel { data.execution_model }
    public var name: String { String(cString: data.name) }
}

extension InternalCompiler {
    
    public var entryPoints: [SPVEntryPoint] {
        var ptr: UnsafePointer<__spvc_entry_point>?
        var size: Int = 0
        
        if compiler.get_entry_points(list: &ptr, size: &size).errorResult != nil {
            fatalError("Out of memory.")
        }
        
        return ptr!.withMemoryRebound(to: SPVEntryPoint.self, capacity: size) {
            Array(UnsafeBufferPointer<SPVEntryPoint>(start: $0, count: size))
        }
    }
    
    public func makeOptions() -> OptionsType {
        var options: SPVCompilerOptions?
        if compiler.create_compiler_options(&options).errorResult != nil {
            fatalError("Out of memory")
        }
        return OptionsType(options: options!)
    }

    public func makeResources() -> SPVResources {
        var resources: SPVResources?
        if compiler.create_shader_resources(&resources).errorResult != nil {
            fatalError("Out of memory")
        }
        
        return resources!
    }
    
    public func compile() throws -> String {
        var src: UnsafePointer<Int8>?
        if let res = compiler.compile(&src).errorResult {
            throw res
        }
        return String(cString: src!)
    }
    
    public func compile(options: OptionsType) throws -> String {
        options.apply(to: compiler)
        return try compile()
    }
    
    public func getType(id: SPVTypeID) -> SPVType? {
        guard let type = compiler.get_type_handle(id) else { return nil }
        return SPVType(compiler: compiler, type: type)
    }
    
    public func getVariable(resource: SPVReflectedResource) -> SPVVariable? {
        SPVVariable(compiler: compiler, id: resource.id, baseTypeID: resource.baseTypeID)
    }
    
    public func name(id: SPVTypeID) -> String {
        String(cString: compiler.get_name(id: id))
    }
}

// MARK: - Accessors

@frozen
public struct CompilerDecorationStringContainer: SPVDecorationContainer {
    public typealias Element = String
    // source: ParsedIR::get_decoration_string
    public static let validKeys: Set<SPVDecoration> = [.hlslSemanticGOOGLE]
    
    let compiler: SPVCompiler
    let id: SpvId
    
    public func hasValue(forKey key: SPVDecoration) -> Bool {
        compiler.has_decoration(id: id, decoration: key)
    }
    
    public func value(forKey key: SPVDecoration) -> Element? {
        guard hasValue(forKey: key) else { return nil }
        return String(cString: compiler.get_decoration_string(id: id, decoration: key))
    }
    
    public func set(value: Element, forKey key: SPVDecoration) {
        value.withCString { ptr in
            compiler.set_decoration_string(id: id, decoration: key, value: ptr)
        }
    }
    
    public func unsetValue(forKey key: SPVDecoration) {
        compiler.unset_decoration(id: id, decoration: key)
    }
}

@frozen
public struct CompilerDecorationUInt32Container: SPVDecorationContainer {
    public typealias Element = UInt32
    // source: ParsedIR::get_decoration
    public static let validKeys: Set<SPVDecoration> = [
        .builtIn, .location, .component, .offset,
        .xfbBuffer, .xfbStride, .binding, .descriptorSet,
        .inputAttachmentIndex, .specId, .arrayStride, .matrixStride,
        .index, .floatingPointRoundingMode,
    ]
    
    let compiler: SPVCompiler
    let id: SpvId
    
    public func hasValue(forKey key: SPVDecoration) -> Bool {
        compiler.has_decoration(id: id, decoration: key)
    }
    
    public func value(forKey key: SPVDecoration) -> Element? {
        guard hasValue(forKey: key) else { return nil }
        return compiler.get_decoration(id: id, decoration: key)
    }
    
    public func set(value: Element, forKey key: SPVDecoration) {
        compiler.set_decoration(id: id, decoration: key, value: value)
    }
    
    public func unsetValue(forKey key: SPVDecoration) {
        compiler.unset_decoration(id: id, decoration: key)
    }
}
