#import "NSInvocation+Cedar.h"
#import "CedarDoubleImpl.h"
#import "StubbedMethod.h"
#import "CDRClassFake.h"

static NSMutableArray *registeredDoubleImpls__ = nil;

@interface CedarDoubleImpl () {
    Cedar::Doubles::StubbedMethod::selector_map_t stubbed_methods_;
}

@property (nonatomic, retain, readwrite) NSMutableArray *sent_messages;
@property (nonatomic, assign) NSObject<CedarDouble> *parent_double;

@end

@implementation CedarDoubleImpl

@synthesize sent_messages = sent_messages_, parent_double = parent_double_;

+ (void)afterEach {
    [CedarDoubleImpl releaseRecordedInvocations];
}

- (id)init {
    [super doesNotRecognizeSelector:_cmd];
    return nil;
}

- (id)initWithDouble:(NSObject<CedarDouble> *)parent_double {
    if (self = [super init]) {
        self.sent_messages = [NSMutableArray array];
        self.parent_double = parent_double;
        [CedarDoubleImpl registerDoubleImpl:self];
    }
    return self;
}

- (void)dealloc {
    self.parent_double = nil;
    self.sent_messages = nil;
    [super dealloc];
}

- (void)reset_sent_messages {
    [self.sent_messages removeAllObjects];
}

- (Cedar::Doubles::StubbedMethod::selector_map_t &)stubbed_methods {
    return stubbed_methods_;
}

- (Cedar::Doubles::StubbedMethod &)add_stub:(const Cedar::Doubles::StubbedMethod &)stubbed_method {
    const SEL & selector = stubbed_method.selector();

    if (![self.parent_double respondsToSelector:selector]) {
        [[NSException exceptionWithName:NSInternalInconsistencyException
                                 reason:[NSString stringWithFormat:@"Attempting to stub method <%s>, which double does not respond to", sel_getName(selector)]
                               userInfo:nil]
          raise];
    }

    Cedar::Doubles::StubbedMethod::selector_map_t::iterator it = stubbed_methods_.find(selector);
    if (it != stubbed_methods_.end()) {
        [[NSException exceptionWithName:NSInternalInconsistencyException
                                 reason:[NSString stringWithFormat:@"The method <%s> is already stubbed", sel_getName(selector)]
                               userInfo:nil] raise];
    }

    stubbed_method.validate_against_instance(self.parent_double);

    Cedar::Doubles::StubbedMethod::shared_ptr_t stubbed_method_ptr = Cedar::Doubles::StubbedMethod::shared_ptr_t(new Cedar::Doubles::StubbedMethod(stubbed_method));
    stubbed_methods_[selector] = stubbed_method_ptr;
    return *stubbed_method_ptr;
}

- (CDRStubInvokeStatus)invoke_stubbed_method:(NSInvocation *)invocation {
    Cedar::Doubles::StubbedMethod::selector_map_t::iterator it = stubbed_methods_.find(invocation.selector);
    if (it == stubbed_methods_.end()) {
        return CDRStubMethodNotStubbed;
    }

    Cedar::Doubles::StubbedMethod::shared_ptr_t stubbed_method_ptr = it->second;
    if (stubbed_method_ptr->matches(invocation)) {
        stubbed_method_ptr->invoke(invocation);
        return CDRStubMethodInvoked;
    } else {
        return CDRStubWrongArguments;
    }
}

- (void)record_method_invocation:(NSInvocation *)invocation {
    [invocation copyBlockArguments];
    [invocation retainArguments];
    [self.sent_messages addObject:invocation];
}

#pragma mark - Private interface

+ (void)releaseRecordedInvocations {
    [registeredDoubleImpls__ makeObjectsPerformSelector:@selector(reset_sent_messages)];
    [registeredDoubleImpls__ release];
    registeredDoubleImpls__ = nil;
}

+ (void)registerDoubleImpl:(CedarDoubleImpl *)doubleImpl {
    if (!registeredDoubleImpls__) {
        registeredDoubleImpls__ = [[NSMutableArray alloc] init];
    }
    [registeredDoubleImpls__ addObject:doubleImpl];
}

@end
