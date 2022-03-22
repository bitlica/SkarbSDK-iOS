//
// DO NOT EDIT.
//
// Generated by the protocol buffer compiler.
// Source: app/install/installapi/api.proto
//

//
// Copyright 2018, gRPC Authors All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
import GRPC
import NIO
import SwiftProtobuf


/// Usage: instantiate `Installapi_IngesterClient`, then call methods of this protocol to make API calls.
internal protocol Installapi_IngesterClientProtocol: GRPCClient {
  var serviceName: String { get }
  var interceptors: Installapi_IngesterClientInterceptorFactoryProtocol? { get }

  func setDevice(
    _ request: Installapi_DeviceRequest,
    callOptions: CallOptions?
  ) -> UnaryCall<Installapi_DeviceRequest, SwiftProtobuf.Google_Protobuf_Empty>

  func setAttribution(
    _ request: Installapi_AttribRequest,
    callOptions: CallOptions?
  ) -> UnaryCall<Installapi_AttribRequest, SwiftProtobuf.Google_Protobuf_Empty>

  func setTest(
    _ request: Installapi_TestRequest,
    callOptions: CallOptions?
  ) -> UnaryCall<Installapi_TestRequest, SwiftProtobuf.Google_Protobuf_Empty>

  func setIDFA(
    _ request: Installapi_IDFARequest,
    callOptions: CallOptions?
  ) -> UnaryCall<Installapi_IDFARequest, SwiftProtobuf.Google_Protobuf_Empty>

  func setASA(
    _ request: Installapi_ASARequest,
    callOptions: CallOptions?
  ) -> UnaryCall<Installapi_ASARequest, SwiftProtobuf.Google_Protobuf_Empty>

  func eraseUserData(
    _ request: Installapi_EraseRequest,
    callOptions: CallOptions?
  ) -> UnaryCall<Installapi_EraseRequest, SwiftProtobuf.Google_Protobuf_Empty>
}

extension Installapi_IngesterClientProtocol {
  internal var serviceName: String {
    return "installapi.Ingester"
  }

  /// Unary call to SetDevice
  ///
  /// - Parameters:
  ///   - request: Request to send to SetDevice.
  ///   - callOptions: Call options.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  internal func setDevice(
    _ request: Installapi_DeviceRequest,
    callOptions: CallOptions? = nil
  ) -> UnaryCall<Installapi_DeviceRequest, SwiftProtobuf.Google_Protobuf_Empty> {
    return self.makeUnaryCall(
      path: "/installapi.Ingester/SetDevice",
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeSetDeviceInterceptors() ?? []
    )
  }

  /// Unary call to SetAttribution
  ///
  /// - Parameters:
  ///   - request: Request to send to SetAttribution.
  ///   - callOptions: Call options.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  internal func setAttribution(
    _ request: Installapi_AttribRequest,
    callOptions: CallOptions? = nil
  ) -> UnaryCall<Installapi_AttribRequest, SwiftProtobuf.Google_Protobuf_Empty> {
    return self.makeUnaryCall(
      path: "/installapi.Ingester/SetAttribution",
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeSetAttributionInterceptors() ?? []
    )
  }

  /// Unary call to SetTest
  ///
  /// - Parameters:
  ///   - request: Request to send to SetTest.
  ///   - callOptions: Call options.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  internal func setTest(
    _ request: Installapi_TestRequest,
    callOptions: CallOptions? = nil
  ) -> UnaryCall<Installapi_TestRequest, SwiftProtobuf.Google_Protobuf_Empty> {
    return self.makeUnaryCall(
      path: "/installapi.Ingester/SetTest",
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeSetTestInterceptors() ?? []
    )
  }

  /// Unary call to SetIDFA
  ///
  /// - Parameters:
  ///   - request: Request to send to SetIDFA.
  ///   - callOptions: Call options.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  internal func setIDFA(
    _ request: Installapi_IDFARequest,
    callOptions: CallOptions? = nil
  ) -> UnaryCall<Installapi_IDFARequest, SwiftProtobuf.Google_Protobuf_Empty> {
    return self.makeUnaryCall(
      path: "/installapi.Ingester/SetIDFA",
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeSetIDFAInterceptors() ?? []
    )
  }

  /// Unary call to SetASA
  ///
  /// - Parameters:
  ///   - request: Request to send to SetASA.
  ///   - callOptions: Call options.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  internal func setASA(
    _ request: Installapi_ASARequest,
    callOptions: CallOptions? = nil
  ) -> UnaryCall<Installapi_ASARequest, SwiftProtobuf.Google_Protobuf_Empty> {
    return self.makeUnaryCall(
      path: "/installapi.Ingester/SetASA",
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeSetASAInterceptors() ?? []
    )
  }

  /// Unary call to EraseUserData
  ///
  /// - Parameters:
  ///   - request: Request to send to EraseUserData.
  ///   - callOptions: Call options.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  internal func eraseUserData(
    _ request: Installapi_EraseRequest,
    callOptions: CallOptions? = nil
  ) -> UnaryCall<Installapi_EraseRequest, SwiftProtobuf.Google_Protobuf_Empty> {
    return self.makeUnaryCall(
      path: "/installapi.Ingester/EraseUserData",
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeEraseUserDataInterceptors() ?? []
    )
  }
}

internal protocol Installapi_IngesterClientInterceptorFactoryProtocol {

  /// - Returns: Interceptors to use when invoking 'setDevice'.
  func makeSetDeviceInterceptors() -> [ClientInterceptor<Installapi_DeviceRequest, SwiftProtobuf.Google_Protobuf_Empty>]

  /// - Returns: Interceptors to use when invoking 'setAttribution'.
  func makeSetAttributionInterceptors() -> [ClientInterceptor<Installapi_AttribRequest, SwiftProtobuf.Google_Protobuf_Empty>]

  /// - Returns: Interceptors to use when invoking 'setTest'.
  func makeSetTestInterceptors() -> [ClientInterceptor<Installapi_TestRequest, SwiftProtobuf.Google_Protobuf_Empty>]

  /// - Returns: Interceptors to use when invoking 'setIDFA'.
  func makeSetIDFAInterceptors() -> [ClientInterceptor<Installapi_IDFARequest, SwiftProtobuf.Google_Protobuf_Empty>]

  /// - Returns: Interceptors to use when invoking 'setASA'.
  func makeSetASAInterceptors() -> [ClientInterceptor<Installapi_ASARequest, SwiftProtobuf.Google_Protobuf_Empty>]

  /// - Returns: Interceptors to use when invoking 'eraseUserData'.
  func makeEraseUserDataInterceptors() -> [ClientInterceptor<Installapi_EraseRequest, SwiftProtobuf.Google_Protobuf_Empty>]
}

internal final class Installapi_IngesterClient: Installapi_IngesterClientProtocol {
  internal let channel: GRPCChannel
  internal var defaultCallOptions: CallOptions
  internal var interceptors: Installapi_IngesterClientInterceptorFactoryProtocol?

  /// Creates a client for the installapi.Ingester service.
  ///
  /// - Parameters:
  ///   - channel: `GRPCChannel` to the service host.
  ///   - defaultCallOptions: Options to use for each service call if the user doesn't provide them.
  ///   - interceptors: A factory providing interceptors for each RPC.
  internal init(
    channel: GRPCChannel,
    defaultCallOptions: CallOptions = CallOptions(),
    interceptors: Installapi_IngesterClientInterceptorFactoryProtocol? = nil
  ) {
    self.channel = channel
    self.defaultCallOptions = defaultCallOptions
    self.interceptors = interceptors
  }
}

/// To build a server, implement a class that conforms to this protocol.
internal protocol Installapi_IngesterProvider: CallHandlerProvider {
  var interceptors: Installapi_IngesterServerInterceptorFactoryProtocol? { get }

  func setDevice(request: Installapi_DeviceRequest, context: StatusOnlyCallContext) -> EventLoopFuture<SwiftProtobuf.Google_Protobuf_Empty>

  func setAttribution(request: Installapi_AttribRequest, context: StatusOnlyCallContext) -> EventLoopFuture<SwiftProtobuf.Google_Protobuf_Empty>

  func setTest(request: Installapi_TestRequest, context: StatusOnlyCallContext) -> EventLoopFuture<SwiftProtobuf.Google_Protobuf_Empty>

  func setIDFA(request: Installapi_IDFARequest, context: StatusOnlyCallContext) -> EventLoopFuture<SwiftProtobuf.Google_Protobuf_Empty>

  func setASA(request: Installapi_ASARequest, context: StatusOnlyCallContext) -> EventLoopFuture<SwiftProtobuf.Google_Protobuf_Empty>

  func eraseUserData(request: Installapi_EraseRequest, context: StatusOnlyCallContext) -> EventLoopFuture<SwiftProtobuf.Google_Protobuf_Empty>
}

extension Installapi_IngesterProvider {
  internal var serviceName: Substring { return "installapi.Ingester" }

  /// Determines, calls and returns the appropriate request handler, depending on the request's method.
  /// Returns nil for methods not handled by this service.
  internal func handle(
    method name: Substring,
    context: CallHandlerContext
  ) -> GRPCServerHandlerProtocol? {
    switch name {
    case "SetDevice":
      return UnaryServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Installapi_DeviceRequest>(),
        responseSerializer: ProtobufSerializer<SwiftProtobuf.Google_Protobuf_Empty>(),
        interceptors: self.interceptors?.makeSetDeviceInterceptors() ?? [],
        userFunction: self.setDevice(request:context:)
      )

    case "SetAttribution":
      return UnaryServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Installapi_AttribRequest>(),
        responseSerializer: ProtobufSerializer<SwiftProtobuf.Google_Protobuf_Empty>(),
        interceptors: self.interceptors?.makeSetAttributionInterceptors() ?? [],
        userFunction: self.setAttribution(request:context:)
      )

    case "SetTest":
      return UnaryServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Installapi_TestRequest>(),
        responseSerializer: ProtobufSerializer<SwiftProtobuf.Google_Protobuf_Empty>(),
        interceptors: self.interceptors?.makeSetTestInterceptors() ?? [],
        userFunction: self.setTest(request:context:)
      )

    case "SetIDFA":
      return UnaryServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Installapi_IDFARequest>(),
        responseSerializer: ProtobufSerializer<SwiftProtobuf.Google_Protobuf_Empty>(),
        interceptors: self.interceptors?.makeSetIDFAInterceptors() ?? [],
        userFunction: self.setIDFA(request:context:)
      )

    case "SetASA":
      return UnaryServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Installapi_ASARequest>(),
        responseSerializer: ProtobufSerializer<SwiftProtobuf.Google_Protobuf_Empty>(),
        interceptors: self.interceptors?.makeSetASAInterceptors() ?? [],
        userFunction: self.setASA(request:context:)
      )

    case "EraseUserData":
      return UnaryServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Installapi_EraseRequest>(),
        responseSerializer: ProtobufSerializer<SwiftProtobuf.Google_Protobuf_Empty>(),
        interceptors: self.interceptors?.makeEraseUserDataInterceptors() ?? [],
        userFunction: self.eraseUserData(request:context:)
      )

    default:
      return nil
    }
  }
}

internal protocol Installapi_IngesterServerInterceptorFactoryProtocol {

  /// - Returns: Interceptors to use when handling 'setDevice'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeSetDeviceInterceptors() -> [ServerInterceptor<Installapi_DeviceRequest, SwiftProtobuf.Google_Protobuf_Empty>]

  /// - Returns: Interceptors to use when handling 'setAttribution'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeSetAttributionInterceptors() -> [ServerInterceptor<Installapi_AttribRequest, SwiftProtobuf.Google_Protobuf_Empty>]

  /// - Returns: Interceptors to use when handling 'setTest'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeSetTestInterceptors() -> [ServerInterceptor<Installapi_TestRequest, SwiftProtobuf.Google_Protobuf_Empty>]

  /// - Returns: Interceptors to use when handling 'setIDFA'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeSetIDFAInterceptors() -> [ServerInterceptor<Installapi_IDFARequest, SwiftProtobuf.Google_Protobuf_Empty>]

  /// - Returns: Interceptors to use when handling 'setASA'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeSetASAInterceptors() -> [ServerInterceptor<Installapi_ASARequest, SwiftProtobuf.Google_Protobuf_Empty>]

  /// - Returns: Interceptors to use when handling 'eraseUserData'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeEraseUserDataInterceptors() -> [ServerInterceptor<Installapi_EraseRequest, SwiftProtobuf.Google_Protobuf_Empty>]
}
