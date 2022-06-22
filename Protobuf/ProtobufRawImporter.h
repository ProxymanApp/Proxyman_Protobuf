//
//  ProtobufImporter.h
//  ProxymanCore
//
//  Created by Nghia Tran on 4/6/20.
//  Copyright © 2020 com.nsproxy.proxy. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ProtobufRawContent;
@class PXProtobufContent;

typedef enum : NSUInteger {
    PXProtobufPayloadModeAuto = 0,
    PXProtobufPayloadModeSingleMessage,
    PXProtobufPayloadModeDelimited,
} PXProtobufPayloadMode;

@protocol ProtobufRawImporterDelegate <NSObject>
-(void) protobufRawImporterOnError:(NSString *) message;
-(void) protobufRawImporterOnWarning:(NSString *) message;
@end

// Dealing with ProtoC++
// Shouldn't use it directly
// Please Use ProtobufImporter.swift
@interface ProtobufRawImporter : NSObject
@property(readonly, nonatomic, nonnull, strong) NSMutableArray<NSString *> *allMessageTypes;
@property(weak, nonatomic, nullable) id<ProtobufRawImporterDelegate> delegate;

+(void) registerRootDirectory:(NSString *) rootDirectory;
+(instancetype) sharedInstance;

-(void) loadProtobufFileWithName:(NSString *) name;
-(void) removeProtobufFileWithNames:(NSArray<NSString *> *) names;
-(void) resetAll;
-(NSArray<PXProtobufContent *> * __nonnull) parseProtobufContentWithMessageType:(NSString *) _messageType from:(NSData *) _data payloadMode:(PXProtobufPayloadMode) mode;
-(void) paresFileDescriptorAtPath:(NSString *) filePath error:(NSError **) errorPtr;

//
// Internal use
//
+(void) addErrorMessage:(NSString *) message;
+(void) addWarningMessage:(NSString *) message;

@end

@interface ProtobufRawContent: NSObject
@property (copy, nonatomic, nullable) NSString *rawMessage;
@property (copy, nonatomic, nullable) NSString *json;
-(instancetype) initWithRawMessage:(NSString * __nullable) rawMessage json:(NSString * __nullable) json;
@end

@interface PXProtobufContentRow: NSObject
@property (copy, nonatomic, nonnull) NSString *fileName;
@property (copy, nonatomic, nonnull) NSString *typeName;
@property (copy, nonatomic, nonnull) NSString *value;
@end

@interface PXProtobufContent: NSObject
@property (copy, nonatomic, nullable) NSString *rawText;
@property (copy, nonatomic, nullable) NSString *error;
@property (assign, nonatomic) BOOL isMissingSchema;

-(instancetype) initWithRawText:(NSString * __nullable) rawText isMissingSchema:(BOOL) isMissingSchema;
-(instancetype) initWithError:(NSString * __nullable) error;
@end
NS_ASSUME_NONNULL_END
