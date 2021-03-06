// Code generated by protoc-gen-go. DO NOT EDIT.
// source: pkg/cri/resource-manager/config/api/v1/api.proto

package v1

import (
	context "context"
	fmt "fmt"
	proto "github.com/golang/protobuf/proto"
	grpc "google.golang.org/grpc"
	codes "google.golang.org/grpc/codes"
	status "google.golang.org/grpc/status"
	math "math"
)

// Reference imports to suppress errors if they are not otherwise used.
var _ = proto.Marshal
var _ = fmt.Errorf
var _ = math.Inf

// This is a compile-time assertion to ensure that this generated file
// is compatible with the proto package it is being compiled against.
// A compilation error at this line likely means your copy of the
// proto package needs to be updated.
const _ = proto.ProtoPackageIsVersion3 // please upgrade the proto package

type SetConfigRequest struct {
	// Name
	NodeName string `protobuf:"bytes,1,opt,name=node_name,json=nodeName,proto3" json:"node_name,omitempty"`
	// Key-value map of ConfigMap data
	Config               map[string]string `protobuf:"bytes,2,rep,name=config,proto3" json:"config,omitempty" protobuf_key:"bytes,1,opt,name=key,proto3" protobuf_val:"bytes,2,opt,name=value,proto3"`
	XXX_NoUnkeyedLiteral struct{}          `json:"-"`
	XXX_unrecognized     []byte            `json:"-"`
	XXX_sizecache        int32             `json:"-"`
}

func (m *SetConfigRequest) Reset()         { *m = SetConfigRequest{} }
func (m *SetConfigRequest) String() string { return proto.CompactTextString(m) }
func (*SetConfigRequest) ProtoMessage()    {}
func (*SetConfigRequest) Descriptor() ([]byte, []int) {
	return fileDescriptor_2d9bc9cf5b527561, []int{0}
}

func (m *SetConfigRequest) XXX_Unmarshal(b []byte) error {
	return xxx_messageInfo_SetConfigRequest.Unmarshal(m, b)
}
func (m *SetConfigRequest) XXX_Marshal(b []byte, deterministic bool) ([]byte, error) {
	return xxx_messageInfo_SetConfigRequest.Marshal(b, m, deterministic)
}
func (m *SetConfigRequest) XXX_Merge(src proto.Message) {
	xxx_messageInfo_SetConfigRequest.Merge(m, src)
}
func (m *SetConfigRequest) XXX_Size() int {
	return xxx_messageInfo_SetConfigRequest.Size(m)
}
func (m *SetConfigRequest) XXX_DiscardUnknown() {
	xxx_messageInfo_SetConfigRequest.DiscardUnknown(m)
}

var xxx_messageInfo_SetConfigRequest proto.InternalMessageInfo

func (m *SetConfigRequest) GetNodeName() string {
	if m != nil {
		return m.NodeName
	}
	return ""
}

func (m *SetConfigRequest) GetConfig() map[string]string {
	if m != nil {
		return m.Config
	}
	return nil
}

type SetConfigReply struct {
	// If not empty, indicate an error that happened while trying to apply new configuration.
	Error                string   `protobuf:"bytes,1,opt,name=error,proto3" json:"error,omitempty"`
	XXX_NoUnkeyedLiteral struct{} `json:"-"`
	XXX_unrecognized     []byte   `json:"-"`
	XXX_sizecache        int32    `json:"-"`
}

func (m *SetConfigReply) Reset()         { *m = SetConfigReply{} }
func (m *SetConfigReply) String() string { return proto.CompactTextString(m) }
func (*SetConfigReply) ProtoMessage()    {}
func (*SetConfigReply) Descriptor() ([]byte, []int) {
	return fileDescriptor_2d9bc9cf5b527561, []int{1}
}

func (m *SetConfigReply) XXX_Unmarshal(b []byte) error {
	return xxx_messageInfo_SetConfigReply.Unmarshal(m, b)
}
func (m *SetConfigReply) XXX_Marshal(b []byte, deterministic bool) ([]byte, error) {
	return xxx_messageInfo_SetConfigReply.Marshal(b, m, deterministic)
}
func (m *SetConfigReply) XXX_Merge(src proto.Message) {
	xxx_messageInfo_SetConfigReply.Merge(m, src)
}
func (m *SetConfigReply) XXX_Size() int {
	return xxx_messageInfo_SetConfigReply.Size(m)
}
func (m *SetConfigReply) XXX_DiscardUnknown() {
	xxx_messageInfo_SetConfigReply.DiscardUnknown(m)
}

var xxx_messageInfo_SetConfigReply proto.InternalMessageInfo

func (m *SetConfigReply) GetError() string {
	if m != nil {
		return m.Error
	}
	return ""
}

func init() {
	proto.RegisterType((*SetConfigRequest)(nil), "v1.SetConfigRequest")
	proto.RegisterMapType((map[string]string)(nil), "v1.SetConfigRequest.ConfigEntry")
	proto.RegisterType((*SetConfigReply)(nil), "v1.SetConfigReply")
}

func init() {
	proto.RegisterFile("pkg/cri/resource-manager/config/api/v1/api.proto", fileDescriptor_2d9bc9cf5b527561)
}

var fileDescriptor_2d9bc9cf5b527561 = []byte{
	// 243 bytes of a gzipped FileDescriptorProto
	0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0xff, 0xe2, 0x32, 0x28, 0xc8, 0x4e, 0xd7,
	0x4f, 0x2e, 0xca, 0xd4, 0x2f, 0x4a, 0x2d, 0xce, 0x2f, 0x2d, 0x4a, 0x4e, 0xd5, 0xcd, 0x4d, 0xcc,
	0x4b, 0x4c, 0x4f, 0x2d, 0xd2, 0x4f, 0xce, 0xcf, 0x4b, 0xcb, 0x4c, 0xd7, 0x4f, 0x2c, 0xc8, 0xd4,
	0x2f, 0x33, 0x04, 0x51, 0x7a, 0x05, 0x45, 0xf9, 0x25, 0xf9, 0x42, 0x4c, 0x65, 0x86, 0x4a, 0x4b,
	0x18, 0xb9, 0x04, 0x82, 0x53, 0x4b, 0x9c, 0xc1, 0x4a, 0x82, 0x52, 0x0b, 0x4b, 0x53, 0x8b, 0x4b,
	0x84, 0xa4, 0xb9, 0x38, 0xf3, 0xf2, 0x53, 0x52, 0xe3, 0xf3, 0x12, 0x73, 0x53, 0x25, 0x18, 0x15,
	0x18, 0x35, 0x38, 0x83, 0x38, 0x40, 0x02, 0x7e, 0x89, 0xb9, 0xa9, 0x42, 0x16, 0x5c, 0x6c, 0x10,
	0x03, 0x25, 0x98, 0x14, 0x98, 0x35, 0xb8, 0x8d, 0x14, 0xf4, 0xca, 0x0c, 0xf5, 0xd0, 0x8d, 0xd0,
	0x83, 0xf0, 0x5c, 0xf3, 0x4a, 0x8a, 0x2a, 0x83, 0xa0, 0xea, 0xa5, 0x2c, 0xb9, 0xb8, 0x91, 0x84,
	0x85, 0x04, 0xb8, 0x98, 0xb3, 0x53, 0x2b, 0xa1, 0xe6, 0x83, 0x98, 0x42, 0x22, 0x5c, 0xac, 0x65,
	0x89, 0x39, 0xa5, 0xa9, 0x12, 0x4c, 0x60, 0x31, 0x08, 0xc7, 0x8a, 0xc9, 0x82, 0x51, 0x49, 0x8d,
	0x8b, 0x0f, 0xc9, 0x8a, 0x82, 0x1c, 0xb0, 0xda, 0xd4, 0xa2, 0xa2, 0xfc, 0x22, 0xa8, 0x7e, 0x08,
	0xc7, 0xc8, 0x91, 0x8b, 0x0d, 0xa2, 0x48, 0xc8, 0x9c, 0x8b, 0x13, 0xae, 0x43, 0x48, 0x04, 0x9b,
	0x1b, 0xa5, 0x84, 0xd0, 0x44, 0x0b, 0x72, 0x2a, 0x95, 0x18, 0x9c, 0x58, 0xa2, 0x98, 0xca, 0x0c,
	0x93, 0xd8, 0xc0, 0x41, 0x64, 0x0c, 0x08, 0x00, 0x00, 0xff, 0xff, 0xb6, 0x6e, 0xc6, 0x28, 0x56,
	0x01, 0x00, 0x00,
}

// Reference imports to suppress errors if they are not otherwise used.
var _ context.Context
var _ grpc.ClientConn

// This is a compile-time assertion to ensure that this generated file
// is compatible with the grpc package it is being compiled against.
const _ = grpc.SupportPackageIsVersion4

// ConfigClient is the client API for Config service.
//
// For semantics around ctx use and closing/ending streaming RPCs, please refer to https://godoc.org/google.golang.org/grpc#ClientConn.NewStream.
type ConfigClient interface {
	SetConfig(ctx context.Context, in *SetConfigRequest, opts ...grpc.CallOption) (*SetConfigReply, error)
}

type configClient struct {
	cc *grpc.ClientConn
}

func NewConfigClient(cc *grpc.ClientConn) ConfigClient {
	return &configClient{cc}
}

func (c *configClient) SetConfig(ctx context.Context, in *SetConfigRequest, opts ...grpc.CallOption) (*SetConfigReply, error) {
	out := new(SetConfigReply)
	err := c.cc.Invoke(ctx, "/v1.Config/SetConfig", in, out, opts...)
	if err != nil {
		return nil, err
	}
	return out, nil
}

// ConfigServer is the server API for Config service.
type ConfigServer interface {
	SetConfig(context.Context, *SetConfigRequest) (*SetConfigReply, error)
}

// UnimplementedConfigServer can be embedded to have forward compatible implementations.
type UnimplementedConfigServer struct {
}

func (*UnimplementedConfigServer) SetConfig(ctx context.Context, req *SetConfigRequest) (*SetConfigReply, error) {
	return nil, status.Errorf(codes.Unimplemented, "method SetConfig not implemented")
}

func RegisterConfigServer(s *grpc.Server, srv ConfigServer) {
	s.RegisterService(&_Config_serviceDesc, srv)
}

func _Config_SetConfig_Handler(srv interface{}, ctx context.Context, dec func(interface{}) error, interceptor grpc.UnaryServerInterceptor) (interface{}, error) {
	in := new(SetConfigRequest)
	if err := dec(in); err != nil {
		return nil, err
	}
	if interceptor == nil {
		return srv.(ConfigServer).SetConfig(ctx, in)
	}
	info := &grpc.UnaryServerInfo{
		Server:     srv,
		FullMethod: "/v1.Config/SetConfig",
	}
	handler := func(ctx context.Context, req interface{}) (interface{}, error) {
		return srv.(ConfigServer).SetConfig(ctx, req.(*SetConfigRequest))
	}
	return interceptor(ctx, in, info, handler)
}

var _Config_serviceDesc = grpc.ServiceDesc{
	ServiceName: "v1.Config",
	HandlerType: (*ConfigServer)(nil),
	Methods: []grpc.MethodDesc{
		{
			MethodName: "SetConfig",
			Handler:    _Config_SetConfig_Handler,
		},
	},
	Streams:  []grpc.StreamDesc{},
	Metadata: "pkg/cri/resource-manager/config/api/v1/api.proto",
}
