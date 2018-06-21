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

@final string NAME = "NAME";
@final string AGE = "AGE";

//import ballerinax/docker;
//import ballerinax/kubernetes;

//@docker:Config {
//    registry:"ballerina.guides.io",
//    name:"chat_app",
//    tag:"v1.0"
//}

//@kubernetes:Ingress {
//    hostname:"ballerina.guides.io",
//    name:"ballerina-guides-chat-app",
//    path:"/"
//}
//
//@kubernetes:Service {
//    serviceType:"NodePort",
//    name:"ballerina-guides-chat-app"
//}
//
//@kubernetes:Deployment {
//    image:"ballerina.guides.io/chat_app:v1.0",
//    name:"ballerina-guides-chat-app"
//}

// Define an endpoint to the chat application
endpoint http:WebSocketListener listener {
    port: 9090
};

// In-memory map to save the connections
map<http:WebSocketListener> consMap;


@http:ServiceConfig {
    basePath: "/chat"
}
service<http:Service> ChatAppUpgrader bind listener {

    //Upgrade from HTTP to WebSocket and define the service the WebSocket client
    @http:ResourceConfig {
        webSocketUpgrade: {
            upgradePath: "/{name}",
            upgradeService: ChatApp
        }
    }
    upgrader(endpoint ep, http:Request req, string name) {
        endpoint http:WebSocketListener wsEp;
        map<string> headers;
        wsEp = ep->acceptWebSocketUpgrade(headers);
        wsEp.attributes[NAME] = name;
        wsEp.attributes[AGE] = req.getQueryParams()["age"];
        string msg = "Hi " + name + "! You have succesfully connected to the chat";
        wsEp->pushText(msg) but {
            error e => log:printError("Error sending message")
        };
    }
}


service<http:WebSocketService> ChatApp {

    // This resource will trigger when a new web socket connection is open
    onOpen(endpoint conn) {
        // Add the new connection to the connection map
        consMap[conn.id] = conn;
        // Broadcast the "new user connected" message to existing connections
        string msg = string `{{getAttributeStr(conn, NAME)}} with age {{getAttributeStr(
                                                                            conn, AGE)}}
         connected to chat`;
        broadcast(consMap, msg);
    }

    // This resource will trigger when a new text message arrives to the chat server
    onText(endpoint conn, string text) {
        // Prepare the message
        string msg = string `{{getAttributeStr(conn, NAME)}}: {{text}}`;
        // Broadcast the message to existing connections
        broadcast(consMap, msg);
        // Print the message in the server console
        log:printInfo(msg);
    }

    // This resource will trigger when a existing connection closed
    onClose(endpoint conn, int statusCode, string reason) {
        // Remove the client from the in memory map
        _ = consMap.remove(conn.id);
        // Prepare the client left message
        string msg = string `{{getAttributeStr(conn, NAME)}} left the chat`;
        // Broadcast the message to existing connections
        broadcast(consMap, msg);
    }
}

// Function to send the test to all connections in the connection map
function broadcast(map<http:WebSocketListener> connections, string text) {
    endpoint http:WebSocketListener ep;
    // Iterate through all available connections in the connections map
    foreach id, con in connections {
        ep = con;
        // Push the text message to the connection
        ep->pushText(text) but {
            error e => log:printError("Error sending message")
        };
    }
}

// Function get attributes from a WebSocket endpoint
function getAttributeStr(http:WebSocketListener ep, string key) returns (string) {
    var name = <string>ep.attributes[key];
    return name;
}