import React, { useState, useEffect } from 'react';
import "./App.css";
import LoginForm from "./LoginForm"

function App() {
  // constructor(props) {
  //   super(props);

  //   const server = new EventSource("http://localhost:3001/stream/a");
  //   server.addEventListener("message", (event) => {
  //     if (event.data === "Goodbye!") {
  //       console.log("Closing SSE connection");
  //       server.close();
  //     } else {
  //       console.log(event.data);
  //     }
  //   });
  //   server.onerror = (_event) => {
  //     console.log("Connection lost, reestablishing");
  //   };
  // }
  const [status, setStatus] = useState('disconnected');
  const [message, setMessage] = useState('');
  const [chatHistory, setChatHistory] = useState([]);
  const [chatURL, setChatURL] = useState('');
  const [messageToken, setMessageToken] = useState(null);
  const [streamToken, setStreamToken] = useState(null);
  const [users, setUsers] = useState(new Set());
  const [showModal, setShowModal] = useState(true);

  useEffect(() => {
    console.log("this is users: ")
    console.log(users)
  }, [users]);
  useEffect(() => {
    if (chatURL && streamToken) {
      const server = new EventSource(
        chatURL + "/stream/" + streamToken
      );
      server.addEventListener(
        "Message",
        function(event) {
          var data = JSON.parse(event.data);
          chatHistory.push(date_format(data.created) + " (" + data.user + ") " + data.message);
          setChatHistory([...chatHistory]);
        },
        false
      );
      server.addEventListener(
        "Users",
        function(event) {
          const users_list = new Set(JSON.parse(event.data).users);
          setUsers(users_list);
        },
        false
      );
      server.addEventListener(
        "Join",
        function(event) {
          var data = JSON.parse(event.data);
          setUsers((prevState) => (new Set([...prevState, data.user])));
          chatHistory.push(date_format(data.created) + " JOIN: " + data.user);
          setChatHistory([...chatHistory]);
          setStatus('connected');
        },
        false
      );
      server.addEventListener(
        "Part",
        function(event) {
          var data = JSON.parse(event.data);
          const remove_user = new Set([data.user])
          setUsers((prevState) => (new Set([...prevState].filter(x => !remove_user.has(x)))));
          chatHistory.push(date_format(data.created) + " PART: " + data.user);
          setChatHistory([...chatHistory]);
        },
        false
      );
      server.addEventListener(
        "Disconnect",
        function(_event) {
            server.close();
            handleDisconnect();
        },
        false
      );
      server.addEventListener(
        "error",
        function(event) {
            if (event.target.readyState == 2) {
                handleDisconnect();
            } else {
                setStatus('disconnected');
                console.log("Disconnected, retrying");
            }
        },
        false
      );
      server.addEventListener(
        "ServerStatus",
        function(event) {
            var data = JSON.parse(event.data);
            chatHistory.push(date_format(data.created) + " STATUS: " + data.status);
            setChatHistory([...chatHistory]);
        },
        false
      );
    }
  }, [chatURL, streamToken])

  function handleDisconnect() {
    setStatus('disconnected');
    setMessage('');
    setChatHistory([]);
    setChatURL('');
    setMessageToken(null);
    setStreamToken(null);
    setUsers(new Set);
    setShowModal(true);
  }

  function date_format(timestamp) {
    var date = new Date(timestamp * 1000);
    return date.toLocaleDateString("en-US") + " " + date.toLocaleTimeString("en-US");
  }

  function sendMessage() {
    const form = new FormData();
    form.append("message", message);

    const request = new XMLHttpRequest();
    request.open("POST", chatURL + "/message");
    request.setRequestHeader(
      "Authorization",
      "Bearer " + messageToken
    );
    request.onreadystatechange = function(event) {
      if (event.target.readyState == 4 && event.target.status != 403 && messageToken != null) {
          setMessageToken(event.target.getResponseHeader("token"));
      }
    }

    request.send(form);
    setMessage('');
  }

  return (
    <div>
      <section id="container">
        <h1 id="title" class={status}>CS291 Chat</h1>
        <div id="window">
            <div id="chat">
              {chatHistory.map((msg) => {
                return <div>{msg}</div>;
              })}
            </div>
            <div id="user_window">
                <h2>Online</h2>
                <ul id="users"></ul>
                {Array.from(users).map((user) => {
                  return <ul>{user}</ul>
                })}
            </div>
        </div>
        <div>
            <input id="message-text" disabled={status == 'disconnected'} type="text" value={status == 'disconnected' ? 'Please connect to send messages.' : message} onChange={(e) => setMessage(e.target.value)}/>
            <button id="message-send-btn" disabled={!message} onClick={sendMessage}>Send</button>
        </div>
    </section>
      {showModal &&
        <LoginForm setStatus={setStatus} setMessageToken={setMessageToken} setStreamToken={setStreamToken} showModal={true} setChatURL={setChatURL} setShowModal={setShowModal} />
      }
    </div>
  );
}
export default App;
