// Copyright (c) 2018 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
//
// WSO2 Inc. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/log;
import ballerina/http;
//import ballerinax/docker;
//import ballerinax/kubernetes;

@final string USER_NAME = "USER_NAME";
@final string AGE = "AGE";

// In-memory map to save the connections
map<http:WebSocketListener> connections;

//@docker:Config {
//    registry:"ballerina.guides.io",
//    name:"chat_app",
//    tag:"v1.0"
//}
//
//@kubernetes:Ingress {
//    hostname: "ballerina.guides.io",
//    name: "ballerina-guides-chat-app",
//    path: "/"
//}
//
//@kubernetes:Service {
//    serviceType: "NodePort",
//    name: "ballerina-guides-chat-app"
//}
//
//@kubernetes:Deployment {
//    image: "ballerina.guides.io/chat_app:v1.0",
//    name: "ballerina-guides-chat-app"
//}
@http:ServiceConfig {
    basePath: "/chat"
}
service<http:Service> ChatAppUpgrader bind { port: 9090 } {

    // Resource to upgrade from HTTP to WebSocket
    @http:ResourceConfig {
        webSocketUpgrade: {
            upgradePath: "/{username}",
            upgradeService: ChatApp
        }
    }
    upgrader(endpoint caller, http:Request req, string username) {
        endpoint http:WebSocketListener wsCaller;
        map<string> headers;
        wsCaller = caller->acceptWebSocketUpgrade(headers);

        // Validate if username is unique
        if (!connections.hasKey(username)){
            wsCaller.attributes[USER_NAME] = username;
        } else {
            wsCaller->close(statusCode = 1003, reason = "Username already exists.") but {
                error e => log:printError("Error sending message", err = e)
            };
            done;
        }

        // Check if the age parameter is available and if so add it to the attributes
        string broadCastMsg;
        match req.getQueryParams()["age"] {
            string age => {
                wsCaller.attributes[AGE] = age;
                broadCastMsg = string `{{username}} with age {{age}} connected to chat`;
            }
            () => {
                broadCastMsg = string `{{username}} connected to chat`;

            }
        }

        // Inform the current user
        wsCaller->pushText("Hi " + username + "! You have succesfully connected to the chat") but {
            error e => log:printError("Error sending message", err = e)
        };

        // Broadcast the "new user connected" message to existing connections
        broadcast(broadCastMsg);

        // Adding the new username to the connections map after broadcasting
        connections[username] = wsCaller;
    }
}


service<http:WebSocketService> ChatApp {

    // This resource will trigger when a new text message arrives to the chat server
    onText(endpoint caller, string text) {
        // Prepare the message
        string msg = string `{{getAttributeStr(caller, USER_NAME)}}: {{text}}`;
        // Broadcast the message to existing connections
        broadcast(msg);
        // Print the message in the server console
        log:printInfo(msg);
    }

    // This resource will trigger when a existing connection closes
    onClose(endpoint caller, int statusCode, string reason) {
        // Remove the client from the in memory map
        _ = connections.remove(getAttributeStr(caller, USER_NAME));
        // Prepare the client left message
        string msg = string `{{getAttributeStr(caller, USER_NAME)}} left the chat`;
        // Broadcast the message to existing connections
        broadcast(msg);
    }
}

// Send the text to all connections in the connections map
function broadcast(string text) {
    endpoint http:WebSocketListener caller;
    // Iterate through all available connections in the connections map
    foreach id, conn in connections {
        caller = conn;
        // Push the text message to the connection
        caller->pushText(text) but {
            error e => log:printError("Error sending message")
        };
    }
}

// Gets attribute for given key from a WebSocket endpoint
function getAttributeStr(http:WebSocketListener ep, string key) returns (string) {
    return <string>ep.attributes[key];
}
