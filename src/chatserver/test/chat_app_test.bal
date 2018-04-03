package chatserver;

import ballerina/net.http;
import ballerina/test;

const string ASSOCIATED_CONNECTION = "ASSOCIATED_CONNECTION";


// Before suite function
@test:BeforeSuite
function beforeFunc () {
    // Start chat server
    _ = test:startServices("chatserver");
}

// After suite function
@test:AfterSuite
function afterFunc () {
    // Stop chat server
    test:stopServices("chatserver");
}

@test:Config
function testChatServer () {
    test:assertTrue(true, msg = "test");
}
