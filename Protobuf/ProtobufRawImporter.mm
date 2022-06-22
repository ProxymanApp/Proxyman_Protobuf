//
//  ProtobufImporter.m
//  ProxymanCore
//
//  Created by Nghia Tran on 4/6/20.
//  Copyright © 2020 com.nsproxy.proxy. All rights reserved.
//

#import "ProtobufRawImporter.h"

#include <iostream>
#include <memory>
#include <google/protobuf/dynamic_message.h>
#include <google/protobuf/compiler/parser.h>
#include <google/protobuf/compiler/importer.h>
#include <google/protobuf/arena.h>
#include <google/protobuf/util/json_util.h>
#include <google/protobuf/unknown_field_set.h>
#include <google/protobuf/util/delimited_message_util.h>
#include <google/protobuf/io/zero_copy_stream_impl.h>
#include <google/protobuf/text_format.h>
#include <google/protobuf/io/coded_stream.h>
#include <google/protobuf/compiler/command_line_interface.h>

using namespace std;
using namespace google::protobuf;
using namespace google::protobuf::io;
using namespace google::protobuf::compiler;
using namespace google::protobuf::util;

@implementation ProtobufRawContent
-(instancetype) initWithRawMessage:(NSString * __nullable) rawMessage json:(NSString * __nullable) json {
    self = [super init];
    if (self) {
        _rawMessage = rawMessage;
        _json = json;
    }
    return self;
}
@end

class ProtobufMultiFileErrorCollector : public compiler::MultiFileErrorCollector
{
public:
    void AddError(const string & filename, int line, int column, const string & message) {
        printf("[ProtobufRawImporter] ⚠️ ERROR: %s\n", message.c_str());

        // Notify the main app
        NSString *error = @(message.c_str());
        [ProtobufRawImporter addErrorMessage:error];
    }
    void AddWarning(const string & filename, int line, int column, const string & message) {
        printf("[ProtobufRawImporter] Warn: %s\n", message.c_str());

        // Notify the main app
        NSString *warning = @(message.c_str());
        [ProtobufRawImporter addWarningMessage:warning];
    }
};

@implementation PXProtobufContent

-(instancetype) initWithRawText:(NSString * __nullable) rawText isMissingSchema:(BOOL) isMissingSchema {
    self = [super init];
    if (self) {
        _rawText = rawText;
        _error = nil;
        _isMissingSchema = isMissingSchema;
    }
    return self;
}

-(instancetype) initWithError:(NSString * __nullable) error {
    self = [super init];
    if (self) {
        _rawText = nil;
        _error = error;
        _isMissingSchema = YES;
    }
    return self;
}
@end

static NSString *_registerRootDirectory = NULL;

@interface ProtobufRawImporter() {
    Arena arena;
    DiskSourceTree source_tree;
    ProtobufMultiFileErrorCollector error_collector;
    Importer *importer;
    DescriptorPool *descriptor_pool;
}
@property (copy, nonatomic) NSString *rootDirectory;
@property(nonatomic, nonnull, strong) NSMutableArray<NSString *> *allMessageTypes;
@property(nonatomic, nonnull, strong) NSMutableArray<NSString *> *protobufFiles;

@end

@implementation ProtobufRawImporter

+(void) registerRootDirectory:(NSString *) rootDirectory {
    _registerRootDirectory = rootDirectory;
}

+(instancetype)sharedInstance {
    // Must call +[ProtobufRawImporter registerRootDirectory:] before using the singleton
    if (_registerRootDirectory == NULL) {
        return nil;
    }

    static ProtobufRawImporter *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ProtobufRawImporter alloc] initWithRootDirectory:_registerRootDirectory];
    });
    return sharedInstance;
}

-(instancetype) initWithRootDirectory:(NSString *) rootDirectory {
    self = [super init];
    if (self) {
        _rootDirectory = rootDirectory;
        std::string root_dir = std::string([rootDirectory UTF8String]);
        source_tree.MapPath("", root_dir); // current at root

        // back-compatible
        // Support *.proto
        importer = Arena::Create<Importer>(&arena, &source_tree, &error_collector);

        // New-version
        // Support *.desc
        descriptor_pool = Arena::Create<DescriptorPool>(&arena);
        descriptor_pool->AllowUnknownDependencies();
        _allMessageTypes = [@[] mutableCopy];
        _protobufFiles = [@[] mutableCopy];
    }
    return self;
}

-(void) loadProtobufFileWithName:(NSString *) name {
    @synchronized (self.protobufFiles) {
        const FileDescriptor *file = importer->Import([name UTF8String]);
        if (file != nullptr) {
            if (![self.protobufFiles containsObject:name]) {
                [self.protobufFiles addObject:name];
            }
            [self getMessageTypeFromFileDescriptor:file];
        }
    }
}

- (NSArray<NSString *> *)getAllMessageTypes {
    return [self.allMessageTypes copy];
}

-(void) removeProtobufFileWithNames:(NSArray<NSString *> *) names {
    // Because there is no way to remove FileDescriptor from DescriptorPool
    // So we have to remove all, then creating new Importer and import the remaining files
    @synchronized (self.protobufFiles) {
        [self.protobufFiles removeObjectsInArray:names];
        NSArray<NSString *> *remainingFiles = [self.protobufFiles copy];

        // flush all
        [self resetAll];

        // Load remaining files (except the delete one)
        for (NSString *filename in remainingFiles) {
            [self loadProtobufFileWithName:filename];
        }
    }
}

-(void) resetAll {
    // Flush all
    arena.Reset();
    [self.allMessageTypes removeAllObjects];
    [self.protobufFiles removeAllObjects];

    // Initialize new importer
    importer = Arena::Create<Importer>(&arena, &source_tree, &error_collector);
    descriptor_pool = Arena::Create<DescriptorPool>(&arena);
    descriptor_pool->AllowUnknownDependencies();
}

-(void) getMessageTypeFromFileDescriptor:(const FileDescriptor *) fileDescriptor {
    @autoreleasepool {
        int count = fileDescriptor->message_type_count();
        for (int i = 0; i < count; i++) {
            const Descriptor *desc = fileDescriptor->message_type(i);
            const std::string full_name = desc->full_name();
            NSString *fullName = [NSString stringWithCString:full_name.c_str() encoding:NSUTF8StringEncoding];
            if (![self.allMessageTypes containsObject:fullName]) {
                // Add at top
                // Make sure the user's Schemas are always at top of the list
                [self.allMessageTypes insertObject:fullName atIndex:0];

                // Display on the main app's console log
                NSString *info = [NSString stringWithFormat:@"Import Message Type = %@", fullName];
                NSLog(@"%@", info);
                [ProtobufRawImporter addInfoMessage:info];
            }
        }
    }
}

-(NSArray<PXProtobufContent *> * __nonnull) parseProtobufContentWithMessageType:(NSString *) _messageType from:(NSData *) _data payloadMode:(PXProtobufPayloadMode) mode {
    if (_data == nil) {
        return @[];
    }

    // Copy to make sure that the data is immutable
    // It hasn't changed during processing -> Avoid crash
    NSData *data = [_data copy];

    // Start
    @autoreleasepool {
        const DescriptorPool* pool = importer->pool();
        NSString *messageType = [_messageType copy];
        string message_type = string([messageType UTF8String]);

        // Find message
        // 1. Find from descriptor_pool, for all desc file
        const Descriptor *message_desc = descriptor_pool->FindMessageTypeByName(message_type);

        // 2. If not found, we try to find from proto pool (back-compatible with old version)
        if (message_desc == NULL) {
            message_desc = pool->FindMessageTypeByName(message_type);
        }

        if (message_desc == NULL) {

            // couldn't find the MessageType in Pool -> Change to Empty and try again
            // It's user-friendly UX
            message_desc = descriptor_pool->FindMessageTypeByName(string("google.protobuf.Empty"));
            messageType = @"google.protobuf.Empty";

            if (message_desc == NULL) {
                NSString *error = [NSString stringWithFormat:@"[ERROR] Cannot get message descriptor of message type %@", messageType];
                return @[[[PXProtobufContent alloc] initWithError:error]];
            }
        }

        // Create an empty Message object that will hold the result of deserializing
        // a byte array for the proto definition:
        DynamicMessageFactory factory;
        const Message* prototype_msg = factory.GetPrototype(message_desc); // prototype_msg is immutable
        if (prototype_msg == NULL) {
            return @[[[PXProtobufContent alloc] initWithError:@"[ERROR] Cannot create prototype message from message descriptor"]];
        }

        // Get message from binary for single message / delimited / auto mode
        NSMutableArray<PXProtobufContent *> *messages = [@[] mutableCopy];
        switch (mode) {
            case PXProtobufPayloadModeSingleMessage: {
                PXProtobufContent *content = [self parseSingleMessageWithData:data prototype:prototype_msg messageType:messageType];
                [messages addObject:content];
                break;
            }
            case PXProtobufPayloadModeDelimited: {
                NSArray<PXProtobufContent *> *subMessages = [self parseDelimitedMessageWithData:data prototype:prototype_msg messageType:messageType];
                [messages addObjectsFromArray:subMessages];
                break;
            }
            case PXProtobufPayloadModeAuto: {
                // Try delimited messages
                NSArray<PXProtobufContent *> *subMessages = [self parseDelimitedMessageWithData:data prototype:prototype_msg messageType:messageType];
                if (subMessages.count > 0) {
                    [messages addObjectsFromArray:subMessages];
                } else {
                    // try single message
                    PXProtobufContent *content = [self parseSingleMessageWithData:data prototype:prototype_msg messageType:messageType];
                    [messages addObject:content];
                }
                break;
            }
            default:
                break;
        }
        return [messages copy];
    }
}

-(PXProtobufContent * __nullable) parseSingleMessageWithData:(NSData *)data prototype:(const Message*) prototype_msg messageType:(NSString *) messageType {
    Message *mutable_msg = prototype_msg->New(&arena);
    if (mutable_msg == NULL) {
        return [[PXProtobufContent alloc] initWithError:@"[ERROR] Failed in prototype_msg->New(); to create mutable message"];
    }

    // Deserialize a binary buffer that contains a message that is described by
    // the proto definition:
    UInt8* buffer = (UInt8 *)data.bytes;
    if (!mutable_msg->ParseFromArray(buffer, int(data.length))) {
        return [self parseToContentFromMessage:mutable_msg messageType:@"google.protobuf.Empty"];
    }
    return [self parseToContentFromMessage:mutable_msg messageType:messageType];
}

-(NSArray<PXProtobufContent *> * __nonnull) parseDelimitedMessageWithData:(NSData *)data prototype:(const Message*) prototype_msg messageType:(NSString *) messageType {
    if (data == nil) {
        return @[];
    }
    // https://developers.google.com/protocol-buffers/docs/techniques#streaming
    UInt8* buffer = (UInt8 *)data.bytes;
    google::protobuf::io::ArrayInputStream fin(buffer, int(data.length));
    NSMutableArray<PXProtobufContent *> *messages = [@[] mutableCopy];

    // Split a huge binary to each protobuf message
    // Delimited messages
    bool success = true;
    while (success) {
        Message* mutable_msg = prototype_msg->New(&arena);
        if (mutable_msg == NULL) {
            PXProtobufContent *content = [[PXProtobufContent alloc] initWithError:@"[ERROR] Failed in prototype_msg->New(); to create mutable message"];
            [messages addObject:content];
            continue;
        }

        success = google::protobuf::util::ParseDelimitedFromZeroCopyStream(mutable_msg, &fin, nullptr);
        if (success) {
            PXProtobufContent *content = [self parseToContentFromMessage:mutable_msg messageType:messageType];
            [messages addObject:content];
        }
    }
    return [messages copy];
}

-(PXProtobufContent * __nonnull) parseToContentFromMessage:(Message *) message messageType:(NSString *) messageType {

    // Get raw text if message Type is absent
    if ([messageType isEqualToString:@"google.protobuf.Empty"]) {
        return [self parseRawFromMessage:message];
    }

    // If everything is good
    // Convert to pretty format
    // JSON
    string json;
    JsonPrintOptions options;
    options.add_whitespace = true;
    options.always_print_primitive_fields = true;
    options.preserve_proto_field_names = true;
    Status status = MessageToJsonString(*message, &json);
    if (status.ok()) {
        NSString *rawText = [NSString stringWithUTF8String:json.c_str()];
        // Somecase the result is {} due to mismatch the message Type
        // try to parse raw
        if ([rawText isEqualToString:@"{}"]) {
            return [self parseRawFromMessage:message];
        }

        // Pretty content
        PXProtobufContent *content = [[PXProtobufContent alloc] initWithRawText:rawText isMissingSchema: NO];
        return content;
    } else {
        string messageError = status.error_message().ToString();
        PXProtobufContent *content = [[PXProtobufContent alloc] initWithError:[NSString stringWithFormat:@"[ERROR] %@", [NSString stringWithUTF8String:messageError.c_str()]]];
        return content;
    }
}

-(PXProtobufContent *) parseRawFromMessage:(Message *) message {
    string output = "";
    TextFormat::PrintToString(*message, &output);
    NSString *rawText = [NSString stringWithUTF8String:output.c_str()];
    PXProtobufContent *content = [[PXProtobufContent alloc] initWithRawText:rawText isMissingSchema:YES];
    return content;
}

+(void) addErrorMessage:(NSString *) message {
    ProtobufRawImporter *shared = [ProtobufRawImporter sharedInstance];
    [shared.delegate protobufRawImporterOnError:[message copy]];
}

+(void) addWarningMessage:(NSString *) message {
    ProtobufRawImporter *shared = [ProtobufRawImporter sharedInstance];
    [shared.delegate protobufRawImporterOnWarning:[message copy]];
}

+ (void)addInfoMessage:(NSString *)message {
    ProtobufRawImporter *shared = [ProtobufRawImporter sharedInstance];
    [shared.delegate protobufRawImporterOnInfo:[message copy]];
}

+(NSError *) initErrorWithMessage:(NSString *) message code:(NSInteger) code {
    NSString *domain = @"com.proxyman.io.protobuf";
    NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:message, @"NSLocalizedDescriptionKey",NULL];
    return [NSError errorWithDomain: domain code: code userInfo: userInfo];
}

-(void) paresFileDescriptorAtPath:(NSString *) filePath error:(NSError **) errorPtr {

    // Read from file
    std::string pathName = std::string([filePath UTF8String]);
    std::vector<std::string> final_args;
    final_args.push_back(pathName);

    google::protobuf::FileDescriptorSet file_descriptor_set;
    for (const auto& input : final_args) {
        int in_fd = ::open(input.c_str(), O_RDONLY);
        if (in_fd < 0) {
            *errorPtr = [ProtobufRawImporter initErrorWithMessage:@"Could not load file" code:101];
            return;
        }
        google::protobuf::io::FileInputStream file_stream(in_fd);
        google::protobuf::io::CodedInputStream coded_input(&file_stream);
        if (!file_descriptor_set.ParseFromCodedStream(&coded_input)) {
            *errorPtr = [ProtobufRawImporter initErrorWithMessage:@"Could not parse the desc file" code:102];
            return ;
        }
        if (!file_stream.Close()) {
            *errorPtr = [ProtobufRawImporter initErrorWithMessage:@"Could not close the file stream" code:103];
            return ;
        }
    }

    for (const auto& d : file_descriptor_set.file()) {
        const FileDescriptor *file = descriptor_pool->BuildFile(d);
        [self getMessageTypeFromFileDescriptor:file];
    }
    return;
}
@end
