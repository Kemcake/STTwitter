//
//  STTwitterRequest.m
//  STTwitterRequests
//
//  Created by Nicolas Seriot on 9/5/12.
//  Copyright (c) 2012 Nicolas Seriot. All rights reserved.
//

#import "STTwitterOAuth.h"
#import "STHTTPRequest.h"

#include <CommonCrypto/CommonHMAC.h>

@interface STTwitterOAuth ()

@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;

@property (nonatomic, retain) NSString *oauthConsumerKey;
@property (nonatomic, retain) NSString *oauthConsumerSecret;

@property (nonatomic, retain) NSString *oauthRequestToken;
@property (nonatomic, retain) NSString *oauthRequestTokenSecret;

@property (nonatomic, retain) NSString *oauthAccessToken;
@property (nonatomic, retain) NSString *oauthAccessTokenSecret;

@property (nonatomic, retain) NSString *testOauthNonce;
@property (nonatomic, retain) NSString *testOauthTimestamp;

@end

@implementation STTwitterOAuth

+ (STTwitterOAuth *)twitterServiceWithConsumerKey:(NSString *)consumerKey consumerSecret:(NSString *)consumerSecret {
    
    STTwitterOAuth *to = [[STTwitterOAuth alloc] init];
    
    to.oauthConsumerKey = consumerKey;
    to.oauthConsumerSecret = consumerSecret;
    
    return [to autorelease];
}

+ (STTwitterOAuth *)twitterServiceWithConsumerKey:(NSString *)consumerKey consumerSecret:(NSString *)consumerSecret oauthToken:(NSString *)oauthToken oauthTokenSecret:(NSString *)oauthTokenSecret {
    
    STTwitterOAuth *to = [self twitterServiceWithConsumerKey:consumerKey consumerSecret:consumerSecret];
    
    to.oauthAccessToken = oauthToken;
    to.oauthAccessTokenSecret = oauthTokenSecret;
    
    return to;
}

+ (STTwitterOAuth *)twitterServiceWithConsumerKey:(NSString *)consumerKey consumerSecret:(NSString *)consumerSecret username:(NSString *)username password:(NSString *)password {
    
    STTwitterOAuth *to = [self twitterServiceWithConsumerKey:consumerKey consumerSecret:consumerSecret];
    
    to.username = username;
    to.password = password;
    
    return to;
}

//+ (NSDictionary *)encodedDictionaryWithDictionary:(NSDictionary *)d {
//    NSMutableDictionary *md = [NSMutableDictionary dictionaryWithCapacity:[d count]];
//    
//    [d enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
//        NSString *encodedKey = [(NSString *)key urlEncodedString];
//        NSString *encodedValue = [(NSString *)obj urlEncodedString];
//
//        md[encodedKey] = encodedValue;
//    }];
//    
//    return md;
//}

+ (NSArray *)encodedParametersDictionaries:(NSArray *)parameters {
    
    NSMutableArray *encodedParameters = [NSMutableArray array];
    
    for(NSDictionary *d in parameters) {
        
        NSString *key = [[d allKeys] lastObject];
        NSString *value = [[d allValues] lastObject];
        
        NSString *encodedKey = [key urlEncodedString];
        NSString *encodedValue = [value urlEncodedString];
        
        //NSString *s = [NSString stringWithFormat:@"%@=\"%@\"", encodedKey, encodedValue];
        
        [encodedParameters addObject:@{encodedKey : encodedValue}];
    }
    
    return encodedParameters;
}

+ (NSString *)stringFromParametersDictionaries:(NSArray *)parametersDictionaries {
    
    NSMutableArray *parameters = [NSMutableArray array];
    
    for(NSDictionary *d in parametersDictionaries) {
        
        NSString *encodedKey = [[d allKeys] lastObject];
        NSString *encodedValue = [[d allValues] lastObject];
        
        NSString *s = [NSString stringWithFormat:@"%@=\"%@\"", encodedKey, encodedValue];
        
        [parameters addObject:s];
    }
    
    return [parameters componentsJoinedByString:@", "];
}

+ (NSString *)oauthHeaderValueWithParameters:(NSArray *)parametersDictionaries {
    
    NSArray *encodedParametersDictionaries = [self encodedParametersDictionaries:parametersDictionaries];
    
    NSString *encodedParametersString = [self stringFromParametersDictionaries:encodedParametersDictionaries];
    
    NSString *headerValue = [NSString stringWithFormat:@"OAuth %@", encodedParametersString];
    
    NSLog(@"-- %@", headerValue);
    
    return headerValue;
}

+ (NSArray *)parametersDictionariesSortedByKey:(NSArray *)parametersDictionaries {
    
    return [parametersDictionaries sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        NSDictionary *d1 = (NSDictionary *)obj1;
        NSDictionary *d2 = (NSDictionary *)obj2;
        
        NSString *key1 = [[d1 allKeys] lastObject];
        NSString *key2 = [[d2 allKeys] lastObject];
        
        return [key1 compare:key2];
    }];
    
}

- (NSString *)oauthNonce {
    if(_testOauthNonce) return _testOauthNonce;
    
    return [NSString random32Characters];
}

- (NSString *)includeEntities {
    return @"true";
}

+ (NSString *)signatureBaseStringWithHTTPMethod:(NSString *)httpMethod url:(NSURL *)url allParametersUnsorted:(NSArray *)parameters {
    NSMutableArray *allParameters = [NSMutableArray arrayWithArray:parameters];
    
    NSArray *encodedParametersDictionaries = [self encodedParametersDictionaries:allParameters];
    
    NSArray *sortedEncodedParametersDictionaries = [self parametersDictionariesSortedByKey:encodedParametersDictionaries];
    
    /**/
    
    NSMutableArray *encodedParameters = [NSMutableArray array];
    
    for(NSDictionary *d in sortedEncodedParametersDictionaries) {
        NSString *encodedKey = [[d allKeys] lastObject];
        NSString *encodedValue = [[d allValues] lastObject];
        
        NSString *s = [NSString stringWithFormat:@"%@=%@", encodedKey, encodedValue];
        
        [encodedParameters addObject:s];
    }
    
    NSString *encodedParametersString = [encodedParameters componentsJoinedByString:@"&"];
    
    NSLog(@"-- encodedParametersString: %@", encodedParametersString);
    
    NSLog(@"-- normalizedURL: %@", [url normalizedForOauthSignatureString]);
    
    NSString *signatureBaseString = [NSString stringWithFormat:@"%@&%@&%@",
                                     [httpMethod uppercaseString],
                                     [[url normalizedForOauthSignatureString] urlEncodedString],
                                     [encodedParametersString urlEncodedString]];
    
    NSLog(@"-- signatureBaseString: %@", signatureBaseString);
    
    return signatureBaseString;
}

+ (NSString *)oauthSignatureWithHTTPMethod:(NSString *)httpMethod url:(NSURL *)url parameters:(NSArray *)parameters consumerSecret:(NSString *)consumerSecret tokenSecret:(NSString *)tokenSecret {
    /*
     The oauth_signature parameter contains a value which is generated by running all of the other request parameters and two secret values through a signing algorithm. The purpose of the signature is so that Twitter can verify that the request has not been modified in transit, verify the application sending the request, and verify that the application has authorization to interact with the user's account.
     https://dev.twitter.com/docs/auth/creating-signature
     */

    NSString *signatureBaseString = [[self class] signatureBaseStringWithHTTPMethod:httpMethod url:url allParametersUnsorted:parameters];
    
    NSLog(@"-- signatureBaseString: %@", signatureBaseString);
    
    /*
     Note that there are some flows, such as when obtaining a request token, where the token secret is not yet known. In this case, the signing key should consist of the percent encoded consumer secret followed by an ampersand character '&'.
     */
    
    NSString *encodedConsumerSecret = [consumerSecret urlEncodedString];
    NSString *encodedTokenSecret = [tokenSecret urlEncodedString];
    
    NSString *signingKey = [NSString stringWithFormat:@"%@&", encodedConsumerSecret];
    
    NSLog(@"-- signing key: %@", signingKey);
    
    if(encodedTokenSecret) {
        signingKey = [signingKey stringByAppendingString:encodedTokenSecret];
    }
    
    NSString *oauthSignature = [signatureBaseString signHmacSHA1WithKey:signingKey];
    
    return oauthSignature;
}

- (BOOL)canVerifyCredentials {
    return (_username && _password);
}

- (void)verifyCredentialsWithSuccessBlock:(void(^)(NSString *username))successBlock errorBlock:(void(^)(NSError *error))errorBlock {
    
    if(_username == nil || _password == nil) return;
    
    [self postXAuthAccessTokenRequestWithUsername:_username password:_password successBlock:^(NSString *oauthToken, NSString *oauthTokenSecret, NSString *userID, NSString *screenName) {
        successBlock(screenName);
    } errorBlock:^(NSError *error) {
        errorBlock(error);
    }];
}

- (NSString *)oauthSignatureMethod {
    return @"HMAC-SHA1";
}

- (NSString *)oauthTimestamp {
    /*
     The oauth_timestamp parameter indicates when the request was created. This value should be the number of seconds since the Unix epoch at the point the request is generated, and should be easily generated in most programming languages. Twitter will reject requests which were created too far in the past, so it is important to keep the clock of the computer generating requests in sync with NTP.
     */
    
    if(_testOauthTimestamp) return _testOauthTimestamp;
    
    NSTimeInterval timeInterval = [[NSDate date] timeIntervalSince1970];
    
    return [NSString stringWithFormat:@"%d", (int)timeInterval];
}

- (NSString *)oauthVersion {
    return @"1.0";
}

- (void)postTokenRequest:(void(^)(NSURL *url, NSString *oauthToken))successBlock errorBlock:(void(^)(NSError *error))errorBlock {

    [self postResource:@"oauth/request_token" baseURLString:@"https://api.twitter.com" parameters:@{} successBlock:^(id body) {
        
        NSDictionary *d = [body parametersDictionary];
        
        NSString *s = [NSString stringWithFormat:@"https://api.twitter.com/oauth/authorize?%@", body];
        
        NSURL *url = [NSURL URLWithString:s];
        
        self.oauthRequestToken = d[@"oauth_token"];
        self.oauthRequestTokenSecret = d[@"oauth_token_secret"]; // unused
        
        successBlock(url, _oauthRequestToken);
        
    } errorBlock:^(NSError *error) {
        NSLog(@"-- error: %@", [error localizedDescription]);
        errorBlock(error);
    }];
}

- (void)postXAuthAccessTokenRequestWithUsername:(NSString *)username
                                       password:(NSString *)password
                                   successBlock:(void(^)(NSString *oauthToken, NSString *oauthTokenSecret, NSString *userID, NSString *screenName))successBlock
                                     errorBlock:(void(^)(NSError *error))errorBlock {
    
    NSDictionary *d = @{@"x_auth_username" : [username urlEncodedString],
                        @"x_auth_password" : [password urlEncodedString],
                        @"x_auth_mode"     : @"client_auth"};
    
    [self postResource:@"oauth/access_token" baseURLString:@"https://api.twitter.com" parameters:d successBlock:^(NSString *body) {
        NSDictionary *d = [body parametersDictionary];
        
        // https://api.twitter.com/oauth/authorize?oauth_token=OAUTH_TOKEN&oauth_token_secret=OAUTH_TOKEN_SECRET&user_id=USER_ID&screen_name=SCREEN_NAME
        
        self.oauthAccessToken = d[@"oauth_token"];
        self.oauthAccessTokenSecret = d[@"oauth_token_secret"];
        
        successBlock(_oauthAccessToken, _oauthAccessTokenSecret, d[@"user_id"], d[@"screen_name"]);
    } errorBlock:^(NSError *error) {
        errorBlock(error);
    }];
}

- (void)postAccessTokenRequestWithPIN:(NSString *)pin
                         successBlock:(void(^)(NSString *oauthToken, NSString *oauthTokenSecret, NSString *userID, NSString *screenName))successBlock
                           errorBlock:(void(^)(NSError *error))errorBlock {

    NSParameterAssert(pin);
    
    NSDictionary *d = @{@"oauth_verifier" : pin};
    
    [self postResource:@"oauth/access_token" baseURLString:@"https://api.twitter.com" parameters:d successBlock:^(NSString *body) {
        NSDictionary *d = [body parametersDictionary];
        
        // https://api.twitter.com/oauth/authorize?oauth_token=OAUTH_TOKEN&oauth_token_secret=OAUTH_TOKEN_SECRET&user_id=USER_ID&screen_name=SCREEN_NAME
        
        self.oauthAccessToken = d[@"oauth_token"];
        self.oauthAccessTokenSecret = d[@"oauth_token_secret"];
                
        successBlock(_oauthAccessToken, _oauthAccessTokenSecret, d[@"user_id"], d[@"screen_name"]);

    } errorBlock:^(NSError *error) {
        errorBlock(error);
    }];
}

- (void)signRequest:(STHTTPRequest *)r isMediaUpload:(BOOL)isMediaUpload {
    NSParameterAssert(_oauthConsumerKey);
    NSParameterAssert(_oauthConsumerSecret);
    
    NSMutableArray *oauthParameters = [NSMutableArray arrayWithObjects:
                                       @{@"oauth_consumer_key"     : [self oauthConsumerKey]},
                                       @{@"oauth_nonce"            : [self oauthNonce]},
                                       @{@"oauth_signature_method" : [self oauthSignatureMethod]},
                                       @{@"oauth_timestamp"        : [self oauthTimestamp]},
                                       @{@"oauth_version"          : [self oauthVersion]}, nil];
    
    if(_oauthAccessToken) { // missing while authenticating with XAuth
        [oauthParameters addObject:@{@"oauth_token" : [self oauthAccessToken]}];
    } else if(_oauthRequestToken) {
        [oauthParameters addObject:@{@"oauth_token" : [self oauthRequestToken]}];
    }
    
    NSString *httpMethod = r.POSTDictionary ? @"POST" : @"GET";
    
    NSMutableArray *oauthAndPOSTParameters = [oauthParameters mutableCopy];
    
    if(r.POSTDictionary) {
        [r.POSTDictionary enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [oauthAndPOSTParameters addObject:@{ key : obj }];
        }];
    }
    
    NSMutableArray *oauthAndPOSTandGETParameters = [[r.url getParametersDictionaries] mutableCopy];
    [oauthAndPOSTandGETParameters addObjectsFromArray:oauthAndPOSTParameters];
    
    NSString *signature = [[self class] oauthSignatureWithHTTPMethod:httpMethod
                                                                 url:r.url
                                                          parameters:isMediaUpload ? oauthParameters : oauthAndPOSTandGETParameters
                                                      consumerSecret:_oauthConsumerSecret
                                                         tokenSecret:_oauthAccessTokenSecret];
    
    [oauthAndPOSTParameters release];
    [oauthAndPOSTandGETParameters release];
    
    [oauthParameters addObject:@{@"oauth_signature" : signature}];
    
    NSString *s = [[self class] oauthHeaderValueWithParameters:oauthParameters];
    
    [r setHeaderWithName:@"Authorization" value:s];
}

- (void)signRequest:(STHTTPRequest *)r {
    [self signRequest:r isMediaUpload:NO];
}

- (void)getResource:(NSString *)resource
         parameters:(NSDictionary *)params
       successBlock:(void(^)(id json))successBlock
         errorBlock:(void(^)(NSError *error))errorBlock {
    
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"https://api.twitter.com/1.1/%@", resource];
    
    NSMutableArray *parameters = [NSMutableArray array];
    
    [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString *s = [NSString stringWithFormat:@"%@=%@", key, obj];
        [parameters addObject:s];
    }];
    
    if([parameters count]) {
        NSString *parameterString = [parameters componentsJoinedByString:@"&"];
        
        [urlString appendFormat:@"?%@", parameterString];
    }
    
    __block STHTTPRequest *r = [STHTTPRequest requestWithURLString:urlString];
    
    [self signRequest:r];
    
    r.completionBlock = ^(NSDictionary *headers, NSString *body) {
        
        NSError *jsonError = nil;
        id json = [NSJSONSerialization JSONObjectWithData:r.responseData options:NSJSONReadingMutableLeaves error:&jsonError];
        NSLog(@"-- jsonError: %@", [jsonError localizedDescription]);
        
        if(json == nil) {
            errorBlock(jsonError);
            return;
        }
        
        NSLog(@"** %@", json);
        
        successBlock(json);
    };
    
    r.errorBlock = ^(NSError *error) {
        NSLog(@"-- body: %@", r.responseString);
        errorBlock(error);
    };
    
    [r startAsynchronous];
}

- (void)postResource:(NSString *)resource
       baseURLString:(NSString *)baseURLString // no trailing slash
          parameters:(NSDictionary *)params
        successBlock:(void(^)(id json))successBlock
          errorBlock:(void(^)(NSError *error))errorBlock {
        
    NSString *urlString = [NSString stringWithFormat:@"%@/%@", baseURLString, resource];
    
    STHTTPRequest *r = [STHTTPRequest requestWithURLString:urlString];

    r.POSTDictionary = params;
    
    // https://dev.twitter.com/docs/api/1.1/post/statuses/update_with_media
    NSData *mediaData = [params valueForKey:@"media[]"];
    
    NSMutableDictionary *mutableParams = [[params mutableCopy] autorelease];
    
    if(mediaData) {
        [mutableParams removeObjectForKey:@"media[]"];

        [r setDataToUpload:mediaData parameterName:@"media[]" mimeType:@"application/octet-stream" fileName:@"media.jpg"];
    }
    
    [self signRequest:r isMediaUpload:(mediaData != nil)];

    // POST parameters must not be encoded while posting media, or spaces will appear as %20 in the status
    r.encodePOSTDictionary = (mediaData == nil);
    
    r.POSTDictionary = mutableParams ? mutableParams : @{};

    r.completionBlock = ^(NSDictionary *headers, NSString *body) {
        successBlock(body);
    };
    
    r.errorBlock = ^(NSError *error) {
        NSLog(@"-- body: %@", r.responseString);
        errorBlock(error);
    };
    
    [r startAsynchronous];
}

- (void)postResource:(NSString *)resource
          parameters:(NSDictionary *)params
        successBlock:(void(^)(id json))successBlock
          errorBlock:(void(^)(NSError *error))errorBlock {
    
    [self postResource:resource baseURLString:@"https://api.twitter.com/1.1" parameters:params successBlock:successBlock errorBlock:errorBlock];
}

@end

@implementation NSURL (STTwitterOAuth)

- (NSArray *)getParametersDictionaries {
    
    NSString *q = [self query];
    
    NSArray *getParameters = [q componentsSeparatedByString:@"&"];
    
    NSMutableArray *ma = [NSMutableArray array];
    
    for(NSString *s in getParameters) {
        NSArray *kv = [s componentsSeparatedByString:@"="];
        NSAssert([kv count] == 2, @"-- bad length");
        if([kv count] != 2) continue;
        [ma addObject:@{kv[0] : kv[1]}];
    }
    
    return ma;
}

- (NSString *)normalizedForOauthSignatureString {
    return [NSString stringWithFormat:@"%@://%@%@", [self scheme], [self host], [self path]];
}

@end

@implementation NSString (STTwitterOAuth)

+ (NSString *)randomString {
    CFUUIDRef cfuuid = CFUUIDCreate (kCFAllocatorDefault);
    NSString *uuid = (NSString *)CFUUIDCreateString (kCFAllocatorDefault, cfuuid);
    CFRelease (cfuuid);
    return [uuid autorelease];
}

+ (NSString *)random32Characters {
    NSString *randomString = [self randomString];
    
    NSAssert([randomString length] >= 32, @"");
    
    return [randomString substringToIndex:32];
}

- (NSString *)signHmacSHA1WithKey:(NSString *)key {
    
    unsigned char buf[CC_SHA1_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA1, [key UTF8String], [key length], [self UTF8String], [self length], buf);
    NSData *data = [NSData dataWithBytes:buf length:CC_SHA1_DIGEST_LENGTH];
    
    return [data base64EncodedString];
}

- (NSDictionary *)parametersDictionary {
    
    NSArray *parameters = [self componentsSeparatedByString:@"&"];
    
    NSMutableDictionary *md = [NSMutableDictionary dictionary];
    
    for(NSString *parameter in parameters) {
        NSArray *keyValue = [parameter componentsSeparatedByString:@"="];
        if([keyValue count] != 2) {
            NSLog(@"-- bad parameter: %@", parameter);
            continue;
        }
        
        [md setObject:keyValue[1] forKey:keyValue[0]];
    }
    
    return md;
}

- (NSString *)urlEncodedString {
    // https://dev.twitter.com/docs/auth/percent-encoding-parameters
    
    NSString *s = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                      (CFStringRef)self,
                                                                      NULL,
                                                                      CFSTR("!*'();:@&=+$,/?%#[]"),
                                                                      kCFStringEncodingUTF8);
    return [s autorelease];
}

@end

@implementation NSData (STTwitterOAuth)

- (NSString *)base64EncodedString {
    
    CFDataRef retval = NULL;
    SecTransformRef encodeTrans = SecEncodeTransformCreate(kSecBase64Encoding, NULL);
    if (encodeTrans == NULL) return nil;
    
    if (SecTransformSetAttribute(encodeTrans, kSecTransformInputAttributeName, (CFDataRef)self, NULL)) {
        retval = SecTransformExecute(encodeTrans, NULL);
    }
    CFRelease(encodeTrans);
    
    NSString *s = [[NSString alloc] initWithData:(NSData *)retval encoding:NSUTF8StringEncoding];
    
    if(retval) {
        CFRelease(retval);
    }
    
    return [s autorelease];
}

@end
