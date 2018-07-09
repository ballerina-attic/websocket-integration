// Initialize the WebSocketConnector
var ws = null;
//The response iframe
var iframe;
// Connect to WebSocket when the connect button clicked
$('#connectBtn').click(function() {
    iframe = document.getElementById("responseBox").contentDocument;

    // Define the WebSocket URL (default one for Ballerina chat app sample
    var url = "ws://localhost:9090/chat/";

    // Get the name and the age of the user
    username = $('#username').val();
    personAge = $('#personAge').val();
    if (username) {
        if (personAge) {
            var age;
            if (!isNaN(personAge) && (age = parseInt(personAge)) < 200 && age > 0) {
                url = url + username + "?age=" + age;
            } else {
                $('#connectionStatus').text("Invalid age parameter").css("color", "red");
                return;
            }
        } else {
            url = url + username.trim();
        }
    } else {
        // username cannot be empty
        $('#connectionStatus').text("Please use a valid username.").css("color", "red");
        return;
    }
    // Create the WebSocket with the Ballerina ws server
    ws = new WebSocket(url);

    // Assign the onMessage function to handle the new messages via WebSocket
    ws.onmessage = onMessage;

    // Assign the onClose function to handle the WebSocket connection terminations
    ws.onclose = onClose;

    //Disable the connect button and enable the other buttons
    document.getElementById("connectBtn").disabled = true;
    document.getElementById("sendTextClrBtn").disabled = false;
    document.getElementById("sendBtn").disabled = false;
    document.getElementById("connectionCloseBtn").disabled = false;

    // Set the connection status
    $('#connectionStatus').text("Successfully connected to server").css("color", "green");
});


// Send the message if user clicks send button
$('#sendBtn').click(function() {
    var text = $('#sendText').val();
    sendMessage(text);
});

// Send the message if user press enter key
$('#sendText').keydown(function(e) {
    if (e.keyCode == 13) {
        var text = $('#sendText').val();
        sendMessage(text);
    }
});

// Close the connection if user pressed Disconnect button
$('#connectionCloseBtn').click(function() {
    closeStatus = true;
    ws.close(1000, "Leaving from chat");
    $('#connectionStatus').text("Disconnected from chat.").css("color", "red");
});

$("#chatForm").submit(function() {
    return false;
});

$("#connectForm").submit(function() {
    return false;
});

$('#sendTextClrBtn').click(function() {
    $('#sendText').val("");
});

function sendMessage(text) {
    // Push the message to the WebSocket
    ws.send(text);
    $('#sendText').val("");
}

function onMessage(msg) {
    text = msg.data;
    // Display the received message in the web page
    if (text) {
        iframe.write(text + "<br>");
        document.getElementById("responseBox").contentWindow.scrollByPages(1);
    }
}

function onClose(evt) {
    if (evt.reason) {
        $('#connectionStatus').text("Disconnected from chat: " + evt.reason).css("color", "red");
    } else {
        $('#connectionStatus').text("Disconnected from chat.").css("color", "red");
    }
    //Enable Connect button and disable other buttons
    document.getElementById("connectBtn").disabled = false;
    document.getElementById("sendTextClrBtn").disabled = true;
    document.getElementById("sendBtn").disabled = true;
    document.getElementById("connectionCloseBtn").disabled = true;

    //close iframe used for writing
    iframe.close();
}
