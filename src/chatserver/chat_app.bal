import ballerina/log;
import ballerina/http;

@final string NAME = "NAME";
@final string AGE = "AGE";

map<http:WebSocketListener> consMap;

// Define an endpoint to the chat application
endpoint http:WebSocketListener ep {
    port:9090
};

@http:ServiceConfig {
    basePath:"/chat"
}
service<http:Service> ChatAppUpgrader bind ep {

//Upgrade from HTTP to WebSocket and define the service the WebSocket client
    @http:ResourceConfig {
        webSocketUpgrade:{
            upgradePath:"/{name}",
            upgradeService:chatApp
        }
    }
    upgrader(endpoint ep, http:Request req, string name) {
        endpoint http:WebSocketListener wsEp;
        map<string> headers;
        wsEp = ep -> acceptWebSocketUpgrade(headers);
        wsEp.attributes[NAME] = name;
        wsEp.attributes[AGE] = req.getQueryParams()["age"];
        string msg = "Hi " + name + "! You have succesfully connected to the chat";
        wsEp -> pushText(msg) but { error e => log:printErrorCause("Error sending message", e) };
    }
}


service<http:WebSocketService> chatApp {

// This resource will trigger when a new web socket connection is open
    onOpen(endpoint conn) {
        // Add the new connection to the connection map
        consMap[conn.id] = conn;
        // Broadcast the "new user connected" message to existing connections
        string msg = string `{{getAttributeStr(conn, NAME)}} with age {{getAttributeStr(conn, AGE)}} connected to chat`;
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
function broadcast(map<http:WebSocketListener> consMap, string text) {
    endpoint http:WebSocketListener ep;
    // Iterate through all available connections in the connections map
    foreach id, con in consMap {
        ep = con;
        // Push the text message to the connection
        ep -> pushText(text) but { error e => log:printErrorCause("Error sending message", e) };
    }
}

// Function get attributes from a WebSocket endpoint
function getAttributeStr(http:WebSocketListener ep, string key) returns (string) {
    var name = <string>ep.attributes[key];
    return name;
}