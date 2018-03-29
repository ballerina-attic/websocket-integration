package chatserver;

import ballerina/io;
import ballerina/net.http;

const string NAME = "NAME";
const string AGE = "AGE";

// Define an endpoint to the chat application
endpoint http:ServiceEndpoint ep {
    port:9090
};

@http:WebSocketServiceConfig {
    basePath:"/chat"
}
service<http:WebSocketService> ChatApp bind ep {
    // In-memory map to store web socket connections
    map<http:WebSocketConnector> consMap = {};
    string msg;

    // This resource will trigger when a new connection upgrades to WebSockets
    onUpgrade (endpoint ep, http:Request req) {
        // Get the query parameters and path parameters to send greeting message
        var params = req.getQueryParams();
        string name = untaint <string>params.name;
        if (name != null) {
            // If client connected with a name
            ep.getClient().attributes[NAME] = name;
            msg = string `{{name}} connected to chat`;
        } else {
            // Throw an error if client connected without a name
            error err = {message:"Please enter a name"};
            throw err;
        }
        string age = untaint <string>params.age;

        if (age != null) {
            // If client has given a age display it in greeting message
            ep.getClient().attributes[AGE] = age;
            msg = string `{{name}} with age {{age}} connected to chat`;
        }
    }

    // This resource will trigger when a new web socket connection is open
    onOpen (endpoint ep) {
        // Get the WebSocket client from the endpoint
        var conn = ep.getClient();
        // Add the new connection to the connection map
        consMap[conn.id] = conn;
        // Broadcast the "new user connected" message to existing connections
        broadcast(consMap, msg);
        // Print the message in the server console
        io:println(msg);
    }

    // This resource wil trigger when a new text message arrives to the chat server
    onTextMessage (endpoint ep, http:TextFrame frame) {
        // Prepare the message
        msg = untaint string `{{untaint <string>ep.getClient().attributes[NAME]}}: {{frame.text}}`;
        // Broadcast the message to existing connections
        broadcast(consMap, msg);
        // Print the message in the server console
        io:println(msg);
    }

    // This resource will trigger when a existing connection closed
    onClose (endpoint ep, http:CloseFrame frame) {
        var con = ep.getClient();
        // Prepare the client left message
        msg = string `{{untaint <string>ep.getClient().attributes[NAME]}} left the chat`;
        // Remove the client from the in memory map
        _ = consMap.remove(con.id);
        // Broadcast the message to existing connections
        broadcast(consMap, msg);
        // Print the message in the server console
        io:println(msg);
    }
}

// Custom function to send the test to all connections in the connection map
function broadcast (map<http:WebSocketConnector> consMap, string text) {
    // Iterate through all available connections in the connections map
    foreach con in consMap {
        // Push the text message to the connection
        con.pushText(text);
    }
}