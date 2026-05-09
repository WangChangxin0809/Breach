# Godot 4

**URL:** https://heroiclabs.com/docs/nakama/client-libraries/godot/
**Summary:** The official Godot 4 client handles all communication in real-time with the server. It implements all features in the server. This guide will show you how to use the core Nakama features in Godot by showing you how to develop the Nakama specific parts of a game.
**Keywords:** godot client guide, godot client, nakama godot, authentication, user accounts, persistence, storage, wallet, status, groups, chat, dynamic chat, real-world example godot
**Categories:** nakama, godot, client-libraries

---


# Nakama Godot 4 Client Guide

This client library guide will show you how to use the core Nakama features in **Godot** by showing you how to develop the Nakama specific parts (without full game logic or UI) of an [Among Us (external)](https://www.innersloth.com/games/among-us/) inspired game called Sagi-shi (Japanese for "Imposter").

<figure>
  <img src={{< fingerprint_image "/images/pages/nakama/client-libraries/gameplay.png" >}} alt="Sagi-shi gameplay screen">
  <figcaption>Sagi-shi gameplay</figcaption>
</figure>

## Prerequisites

Before proceeding ensure that you have:

* Installed [Nakama server](../../getting-started/install/docker/)
* [Downloaded and installed Godot](https://godotengine.org/download)
* [Installed the Nakama Godot SDK](#installation)

### Installation

The client is available from the:

* [Godot Asset Library](https://godotengine.org/asset-library/asset)
* [Heroic Labs GitHub releases page](https://github.com/heroiclabs/nakama-godot/releases/latest)

After downloading the client archive extract its contents into your Godot project folder.

From the `Project -> Project Settings -> Autoload` menu add the `Nakama.gd` singleton (found in `addons/com.heroiclabs.nakama/`).

Create a [client object](#nakama-client) to interact with the server.

#### Updates

New versions of the Nakama Godot Client and the corresponding improvements are documented in the [Changelog](https://github.com/heroiclabs/nakama-godot/blob/master/CHANGELOG.md).


### Asynchronous programming

Many of the Nakama APIs are asynchronous and non-blocking and are available in the Godot SDK as async methods.

Sagi-shi calls async methods using the `await` operator to not block the calling thread so that the game is responsive and efficient.

```gdscript
await client.authenticate_device_async("<device_id>)
```

Read more about coroutines and `await` in the [official Godot documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html#awaiting-for-signals-or-coroutines).


### Handling exceptions

Network programming requires additional safeguarding against connection and payload issues.

Godot does not support exception handling, so instead we can use the `is_exception()` method when making async requests:

```gdscript
var invalid_session = NakamaSession.new() # An empty session, which will cause an error
var invalid_account = await client.get_account_async(invalid_session)
print(invalid_account) # This will print the exception
if invalid_account.is_exception():
    print("We got an exception.")
```


### Serializing and deserializing data

When sending and receiving data across the network it will need to be serialized and deserialized appropriately. The two most common ways to do this are using JSON and Binary data.

Both examples will show how to serialize and deserialize the `Dictionary` object below but can be used with any `Variant` object.

```gdscript
var data = {
  "Key": "Value",
  "AnotherKey": "AnotherValue"
}
```


#### JSON

Godot has native support for serializing and deserializing to JSON using the global `JSON` object.

```gdscript
// Serialize
var serialized = JSON.stringify(data)

// Deserialize
var deserialized = JSON.parse_string(serialized)
```


#### Binary

Godot can serialize and deserialize to `byte[]` arrays using the globally accessible `var_to_bytes` and `bytes_to_var` functions.

```gdscript
// Serialize
var serialized = var_to_bytes(data)

// Deserialize
var deserialized = bytes_to_var(serialized)
```


## Getting started

Learn how to get started using the Nakama Client and Socket objects to start building Sagi-shi and your own game.


### Nakama Client

The Nakama Client connects to a Nakama Server and is the entry point to access Nakama features. It is recommended to have one client per server per game.

To create a client for Sagi-shi pass in your server connection details:

```gdscript
extends Node

var client : NakamaClient

func _ready():
    client = Nakama.create_client("defaultkey", "127.0.0.1", 7350, "http")
```

### Configuring the Request Timeout Length

Each request to Nakama from the client must complete in a certain period of time before it is considered to have timed out. You can configure how long this period is (in seconds) by setting the `timeout` value on the client:

```gdscript
client.timeout = 10
```


### Nakama Socket

The Nakama Socket is used for gameplay and real-time latency-sensitive features such as chat, parties, matches and RPCs.

From the client create a socket:

```gdscript
# Make this a node variable or it will disconnect when the function that creates it returns

@onready var socket = Nakama.create_socket_from(client)

func _ready():
    var connected : NakamaAsyncResult = await socket.connect_async(session)
    if connected.is_exception():
        print("An error occurred: %s" % connected)
        return
    print("Socket connected.")
```


## Authentication

Nakama has many [authentication methods](../../concepts/authentication/) and supports creating [custom authentication](../../concepts/authentication/#custom) on the server.

Sagi-shi will use device and Facebook authentication, linked to the same user account so that players can play from multiple devices.

<figure>
  <img src={{< fingerprint_image "/images/pages/nakama/client-libraries/login.png" >}} alt="Sagi-shi login screen">
  <figcaption>Login screen and Authentication options</figcaption>
</figure>


### Device authentication

Nakama [Device Authentication](../../concepts/authentication/#device) uses the physical device's unique identifier to easily authenticate a user and create an account if one does not exist.

When using only device authentication, you don't need a login UI as the player can automatically authenticate when the game launches.

Authentication is an example of a Nakama feature accessed from a Nakama Client instance.

```gdscript
# Get the System's unique device identifier
var device_id = OS.get_unique_id()

# Authenticate with the Nakama server using Device Authentication
var session : NakamaSession = await client.authenticate_device_async(device_id)
if session.is_exception():
    print("An error occurred: %s" % session)
    return
print("Successfully authenticated: %s" % session)
```


### Facebook authentication

Nakama [Facebook Authentication](../../concepts/authentication/#facebook) is an easy to use authentication method which lets you optionally import the player's Facebook friends and add them to their Nakama Friends list.

```gdscript
var oauth_token = "<token>"
var import_friends = true
var session : NakamaSession = await client.authenticate_facebook_async(oauth_token, import_friends)
if session.is_exception():
    print("An error occurred: %s" % session)
    return
print("Successfully authenticated: %s" % session)
```

### Custom authentication

Nakama supports [Custom Authentication](../../concepts/authentication/#custom) methods to integrate with additional identity services.

See the [Itch.io custom authentication](../../client-libraries/snippets/custom-authentication/) snippet for an example.

### Linking authentication

Nakama allows players to [Link Authentication](../../concepts/authentication/#link-or-unlink) methods to their account once they have authenticated.


**Linking Device ID authentication**

```gdscript
var device_id = "<unique_device_id>"

# Link Device Authentication to existing player account.
var linked : NakamaAsyncResult = await client.link_custom_async(session, device_id)
if linked.is_exception():
    print("An error occurred: %s" % linked)
    return
print("Id '%s' linked for user '%s'" % [device_id, session.user_id])
```

**Linking Facebook authentication**

```gdscript
var oauth_token = "<token>"
var import_friends = true
var session : NakamaSession = await client.link_facebook_async(session, oauth_token, import_friends)
if session.is_exception():
    print("An error occurred: %s" % linked)
    return
print("Facebook authentication linked for user '%s'" % [session.user_id])
```

### Session variables

Nakama [Session Variables](../../concepts/session/#session-variables) can be stored when authenticating and will be available on the client and server as long as the session is active.

Sagi-shi uses session variables to implement analytics, referral and rewards programs and more.

Store session variables by passing them as an argument when authenticating:

```gdscript
var vars = {
    "device_os" : OS.get_name,
    "device_model" : OS.get_model_name,
    "invite_user_id" : "<some_user_id>,
    # ...
}

var session : NakamaSession = await client.authenticate_device_async("<device_id>", null, true, vars)
```

To access session variables on the Client use the `Vars` property on the `Session` object:

```gdscript
var device_os = session.vars["device_os"];
```

### Session lifecycle

Nakama [Sessions](../../concepts/session/) expire after a time set in your server [configuration](../../getting-started/configuration/#session). Expiring inactive sessions is a good security practice.

Nakama provides ways to restore sessions, for example when Sagi-shi players re-launch the game, or refresh tokens to keep the session active while the game is being played.

Use the auth and refresh tokens on the session object to restore or refresh sessions.

Restore a session without having to re-authenticate:

```gdscript
var auth_token = "restored from save location"
var session = NakamaClient.restore_session(auth_token)
```

Check if a session has expired or is close to expiring and refresh it to keep it alive:

```gdscript
# Check whether a session has expired or is close to expiry
if session.expired:
    # Attempt to refresh the existing session.
    session = await client.session_refresh_async(session)
    if session.is_exception():
        # Couldn't refresh the session so reauthenticate.
        session = await client.authenticate_device_async(device_id)
        # Save the new refresh token
        <save_file>.set_value("refresh_token", session.refresh_token)
    }

    # Save the new auth token
    <save_file>.set_value("auth_token", session.auth_token)
}
```


### Ending sessions

Logout and end the current session:

```gdscript
await client.session_logout_async(session)
```


## User accounts

Nakama [User Accounts](../../concepts/user-accounts/) store user information defined by Nakama and custom developer metadata.

Sagi-shi allows players to edit their accounts and stores metadata for things like game progression and in-game items.

<figure>
  <img src={{< fingerprint_image "/images/pages/nakama/client-libraries/profile.png" >}} alt="Sagi-shi player profile screen">
  <figcaption>Player profile</figcaption>
</figure>


### Get the user account

Many of Nakama's features are accessible with an authenticated session, like [fetching a user account](../../concepts/user-accounts/#fetch-account).

Get a Sagi-shi player's full user account with their basic [user information](../../concepts/user-accounts/#fetch-account) and user id:

```gdscript
var account = await client.get_account_async(session)
var username = account.user.username
var avatar_url = account.user.avatar_url
var user_id = account.user.id
```

### Update the user account

Nakama provides easy methods to update server stored resources like user accounts.

Sagi-shi players need to be able to update their public profiles:

```gdscript
var new_username = "NotTheImp0ster"
var new_display_name = "Innocent Dave"
var new_avatar_url = "https://example.com/imposter.png"
var new_lang_tag = "en"
var new_location = "Edinburgh"
var new_timezone = "BST"
await client.update_account_async(session, new_username, new_display_name, new_avatar_url, new_lang_tag, new_location, new_timezone)
```


### Getting users

In addition to getting the current authenticated player's user account, Nakama has a convenient way to get a list of other players' public profiles from their ids or usernames.

Sagi-shi uses this method to display player profiles when engaging with other Nakama features:

```gdscript
var ids = ["userid1", "userid2"]
var users : NakamaAPI.ApiUsers = await client.get_users_async(session, ids)
```


### Storing metadata

Nakama [User Metadata](../../concepts/user-accounts/#user-metadata) allows developers to extend user accounts with public user fields.

User metadata can only be updated on the server. See the [updating user metadata](../../client-libraries/snippets/user-metadata) recipe for an example.

Sagi-shi will use metadata to store what in-game items players have equipped:


### Reading metadata

Define a class that describes the metadata and parse the JSON metadata:

```gdscript
class_name metadata

@export var title: String
@export var hat: String
@export var skin: String

# Get the updated account object
var account : NakamaAPI.ApiAccount = await client.get_account_async(session)

# Parse the account user metadata.
var metadata = JSON.parse_string(account.user.metadata)

Print("Title: %s", metadata.title)
Print("Hat: %s", metadata.hat)
Print("Skin: %s", metadata.skin)
```


### Wallets

Nakama [User Wallets](../../concepts/user-accounts/#virtual-wallet) can store multiple digital currencies as key/value pairs of strings/integers.

Players in Sagi-shi can unlock or purchase titles, skins and hats with a virtual in-game currency.


#### Accessing wallets

Parse the JSON wallet data from the user account:

```gdscript
var account : NakamaAPI.ApiAccount = await client.get_account_async(session)
var wallet = JSON.parse_string(account.wallet)
for currency in wallet
    Print("%s, %s" % [currency, wallet[currency].string(int from)])
```


#### Updating wallets

Wallets can only be updated on the server. See the [user account virtual wallet](../../concepts/user-accounts/#virtual-wallet) documentation for an example.


#### Validating in-app purchases

Sagi-shi players can purchase the virtual in-game currency through in-app purchases that are authorized and validated to be legitimate on the server.

See the [In-app Purchase Validation](../../concepts/iap-validation/) documentation for examples.


## Storage Engine

The Nakama [Storage Engine](../../concepts/storage/) is a distributed and scalable document-based storage solution for your game.

The Storage Engine gives you more control over how data can be [accessed](../../concepts/storage/permissions/#object-permissions) and [structured](../../concepts/storage/collections/) in collections.

Collections are named, and store JSON data under a unique key and the user id.

By default, the player has full permission to create, read, update and delete their own storage objects.

Sagi-shi players can unlock or purchase many items, which are stored in the Storage Engine.

<figure>
  <img src={{< fingerprint_image "/images/pages/nakama/client-libraries/player-items.png" >}} alt="Sagi-shi player items screen">
  <figcaption>Player items</figcaption>
</figure>


### Reading storage objects

Read the storage objects and parse the JSON data:

```gdscript
var read_object_id = NakamaStorageObjectId.new("unlocks", "hats", session.user_id)

var result : NakamaAPI.ApiStorageObjects = await client.read_storage_objects_async(session, read_object_id)

print("Unlocked hats: ")
for o in result.objects:
    print("%s" % o)
```

To read other players' public storage object, use their `user_id` instead.
Players can only read storage objects they own or that are public (`PermissionRead` value of `2`).


### Writing storage objects

Nakama allows developers to write to the Storage Engine from the client and server.

Consider what adverse effects a malicious user can have on your game and economy when deciding where to put your write logic, for example data that should only be written authoritatively (i.e. game unlocks or progress).

Sagi-shi allows players to favorite items for easier access in the UI and it is safe to write this data from the client.

Write the storage objects to the Storage Engine:

```gdscript
var favorite_hats = ["cowboy", "alien"]
var can_read = 1 # Only the server and owner can read
var can_write = 1 # The server and owner can write

var acks : NakamaAPI.ApiStorageObjectAcks = await client.write_storage_objects_async(session, [
    NakamaWriteStorageObject.new("hats", "favorite_hats", can_read, can_write)])
```

You can also pass multiple objects to the `write_storage_objects_async` method:

```gdscript
var acks : NakamaAPI.ApiStorageObjectAcks = await client.write_storage_objects_async(session, [
    NakamaWriteStorageObject.new(...),
    NakamaWriteStorageObject.new(...)
])
```

### Conditional writes

Storage Engine [Conditional Writes](../../concepts/storage/collections/#conditional-writes) ensure that write operations only happen if the object hasn't changed since you accessed it.

This gives you protection from overwriting data, for example the Sagi-shi server could have updated an object since the player last accessed it.

To perform a conditional write, add a version to the write storage object with the most recent object version:

```gdscript
# Assuming we already have a storage object
var favorite_hats = ["cowboy", "alien"]
var can_read = 1 # Only the server and owner can read
var can_write = 1 # The server and owner can write
var version = <version>

var acks : NakamaAPI.ApiStorageObjectAcks = await client.write_storage_objects_async(session, [
    NakamaWriteStorageObject.new("hats", "favorite_hats", can_read, can_write, version)])
if acks.is_exception():
    print("An error occurred: %s" % acks)
    return
```

### Listing storage objects

Instead of doing multiple read requests with separate keys you can list all the storage objects the player has access to in a collection.

Sagi-shi lists all the player's unlocked or purchased titles, hats and skins:

```gdscript
var limit = 3
var unlocks_object_list : NakamaAPI.ApiStorageObjectList = await client.list_storage_objects_async(session, "titles", "hats", "skins", session.user_id, limit)
if unlocks_object_list.is_exception():
    print("An error occurred: %s" % unlocks_object_list)
    return
print("Unlocked objects: ")
for o in unlocks_object_list.objects:
    print("%s" % o)
```


### Paginating results

Nakama methods that list results return a cursor which can be passed to subsequent calls to Nakama to indicate where to start retrieving objects from in the collection.

For example:
- If the cursor has a value of 5, you will get results from the fifth object.
- If the cursor is `null`, you will get results from the first object.

```gdscript
object_list : NakamaAPI.ApiStorageObjectList = await client.list_storage_objects_async(session, "<object>", limit, object_list.cursor)
```


### Protecting storage operations on the server

Nakama Storage Engine operations can be protected on the server to protect data the player shouldn't be able to modify (i.e.  game unlocks or progress). See the [writing to the Storage Engine authoritatively](../../client-libraries/snippets/authoritative-write/) recipe.


## Remote Procedure Calls

The Nakama [Server](../../server-framework/) allows developers to write custom logic and expose it to the client as [RPCs](../../server-framework/introduction/#functionality).

Sagi-shi contains various logic that needs to be protected on the server, like checking if the player owns equipment before equipping it.


### Creating server logic

See the [handling player equipment authoritatively](../../client-libraries/snippets/authoritative-read/) recipe for an example of creating a remote procedure to check if the player owns equipment before equipping it.


### Client RPCs

Nakama Remote Procedures can be called from the client and take optional JSON payloads.

The Sagi-shi client makes an RPC to securely equip a hat:

```gdscript
var payload = {"hat": "cowboy"}
var rpc_id = equip_hat
var response : NakamaAPI.ApiRpc = await client.rpc_async(session, rpc_id, JSON.stringify(payload))
if response.is_exception():
    print("An error occurred: %s" % response)
    return
```


### Socket RPCs

Nakama Remote Procedures can also be called from the socket when you need to interface with Nakama's real-time functionality. These real-time features require a live socket (and corresponding session identifier). RPCs can be made on the socket carrying this same identifier.

```gdscript
var response : NakamaAPI.ApiRpc = await socket.rpc_async("<rpc_id>", "<payload>")
```


## Friends

Nakama [Friends](../../concepts/friends/) offers a complete social graph system to manage friendships amongst players.

Sagi-shi allows players to add friends, manage their relationships and play together.

<figure>
  <img src={{< fingerprint_image "/images/pages/nakama/client-libraries/friends.png" >}} alt="Sagi-shi Friends screen">
  <figcaption>Friends screen</figcaption>
</figure>


### Adding friends

Adding a friend in Nakama does not immediately add a mutual friend relationship. An outgoing friend request is created to each user, which they will need to accept.

Sagi-shi allows players to add friends by their usernames or user ids:

```gdscript
var ids = ["some_user_id", "another_user_id]
var usernames = ["AlwaysTheImposter21", "SneakyBoi"]

# Add friends by username
var result : NakamaAsyncResult = await client.add_friends_async(session, usernames)

# Add friends by user id
var result : NakamaAsyncResult = await client.add_friends_async(session, ids)
```


### Friendship states

Nakama friendships are categorized with the following [states](../../concepts/friends/#friend-state):

| Value | State |
| 
----- | ----- |
| 0 | Mutual friends |
| 1 | An outgoing friend request pending acceptance |
| 2 | An incoming friend request pending acceptance |
| 3 | Blocked by the user |


### Listing friends

Nakama allows developers to list the player's friends based on their [friendship state](../../concepts/friends/#friend-state).

Sagi-shi lists the 20 most recent mutual friends:

```gdscript
var limit = 20 # Limit is capped at 1000
var friendship_state = 0
var list : NakamaAPI.ApiFriendList = await client.list_friends_async(session, limit, friendship_state)
if list.is_exception():
    print("An error occurred: %s" % list)
    return
for f in list.friends:
    var friend = f as NakamaAPI.ApiFriend
    print("Friends %s [friend.user.id])
```


### Accepting friend requests

When accepting a friend request in Nakama the player adds a [bi-directional friend relationship](../../concepts/friends/best-practices/#modeling-relationships).

Nakama takes care of changing the state from pending to mutual for both.

In a complete game you would allow players to accept individual requests.

Sagi-shi just fetches and accepts all the incoming friend requests:

```gdscript
var limit = 1000
var result : NakamaAsyncResult = await client.list_friends_async(session, 2, limit, cursor: null)
for f in result.friends:
    await client.add_friend_async(session, f.user.id)
```


### Deleting friends

Sagi-shi players can decline friend requests and remove friends by their username or user id:

```gdscript
var ids = ["some_user_id", "another_user_id]
var usernames = ["AlwaysTheImposter21", "SneakyBoi"]

# Delete friends by username
var result : NakamaAsyncResult = await client.delete_friends_async(session, usernames)

# Delete friends by user id
var result : NakamaAsyncResult = await client.delete_friends_async(session, ids)
```


### Blocking users

Sagi-shi players can block others by their username or user id:

```gdscript
var ids = ["some_user_id", "another_user_id]
var usernames = ["AlwaysTheImposter21", "SneakyBoi"]

# Block friends by username
var result : NakamaAsyncResult = await client.block_friends_async(session, usernames)

# Block friends by user id
var result : NakamaAsyncResult = await client.block_friends_async(session, ids)
```

Learn more about [blocking friends](../../concepts/friends/#block-a-friend) and the associated [relationship states](../../concepts/friends/best-practices/#relationship-state).

Blocked users can listed just like [listing friends](#listing-friends) but using the corresponding friendship state (`3`).


## Status & Presence

Nakama [Status](../../concepts/status/) is a real-time status and presence service that allows users to set their online presence, update their status message and follow other user's updates.

Players don't have to be friends with others they want to follow.

Sagi-shi uses status messages and online presences to notify players when their friends are online and share matches.

<figure>
  <img src={{< fingerprint_image "/images/pages/nakama/client-libraries/status.png" >}} alt="Sagi-shi status update screen">
  <figcaption>Updating player status</figcaption>
</figure>


### Follow users

The Nakama real-time APIs allow developers to subscribe to events on the socket, like a status presence change, and receive them in real-time.

The method to [follow users](../../concepts/status/#follow-users) also returns the current online users, known as presences, and their status.

Sagi-shi follows a player's friends and notifies them when they are online:

```gdscript
func _ready():
    # Setup the socket and subscribe to the status event
    socket.received_status_presence.connect(self._on_status_presence)

func _on_status_presence(p_presence : NakamaRTAPI.StatusPresenceEvent):
    print(p_presence)
    for j in p_presence.joins:
        print("%s is online with status: %s" % [j.user_id, j.status])
    for j in p_presence.leaves:
        print("%s went offline" % [j.user_id])

# Follow mutual friends and get the initial Status of any that are currently online
var friends_result = await client.list_friends_async(session, 0)
var friend_ids = []
for friend in friends_result:
	var f = friend as NakamaAPI.ApiFriend
	if not f or not f.user.online:
		continue
	friend_ids.append(f.user)
var result : NakamaAsyncResult = await socket.follow_users_async(friend_ids)

for p in result.presences:
    print("%s is online with status: %s" % [presence.user_id, presence.status])
```


### Unfollow users

Sagi-shi players can unfollow others:

```gdscript
await socket.unfollow_users_async("<user_id>")
```


### Updating player status

Sagi-shi players can change and publish their status to their followers:

```gdscript
await socket.update_status_async("Viewing the Main Menu")
```


## Groups

Nakama [Groups](../../concepts/groups/) is a group or clan system with public/private visibility, user memberships and permissions, metadata and group chat.

Sagi-shi allows players to form and join groups to socialize and compete.

<figure>
  <img src={{< fingerprint_image "/images/pages/nakama/client-libraries/groups-list.png" >}} alt="Sagi-shi groups screen">
  <figcaption>Groups list screen</figcaption>
</figure>


### Creating groups

Groups have a public or private "open" visibility. Anyone can join public groups, but they must request to join and be accepted by a superadmin/admin of a private group.

Sagi-shi players can create groups around common interests:

```gdscript
var name = "Imposters R Us"
var description = "A group for people who love playing the imposter."
var open = true # public group
var max_size = 100

var group : NakamaAPI.ApiGroup = await client.create_group_async(session, name, description, open, max_size)
```

### Update group visibility

Nakama allows group superadmin or admin members to update some properties from the client, like the open visibility:

```gdscript
var open = false
await client.update_group_async(session, "<group_id>", name: null, open)
```


### Update group size

Other properties, like the group's maximum member size, can only be changed on the server.

See the [updating group size](../../concepts/groups/#updating-group-size) recipe for an example, and the [Groups server function reference](../../server-framework/typescript-runtime/function-reference/#groups) to learn more about updating groups on the server.

<figure>
  <img src={{< fingerprint_image "/images/pages/nakama/client-libraries/group-edit.png" >}} alt="Sagi-shi group edit screen">
  <figcaption>Sagi-shi group edit</figcaption>
</figure>


### Listing and filtering groups

Groups can be listed like other Nakama resources and also [filtered](../../concepts/groups/#list-and-filter-groups) with a wildcard group name.

Sagi-shi players use group listing and filtering to search for existing groups to join:


```gdscript
var limit = 20
var result : NakamaAPI.ApiGroupList = await client.list_groups_async(session, "imposter%", limit)

for g in result.groups:
    var group = g as NakamaAPI.ApiGroup
    print("Group: name &s, open %s", [group.name, group.open])

$ Get the next page of results
var next_results : NakamaAPI.ApiGroupList = await client.list_groups_async(session, name: "imposter%", limit, result.cursor)
```


### Deleting groups

Nakama allows group superadmins to delete groups.

Developers can disable this feature entirely, see the [Guarding APIs guide](../../guides/server-framework/guarding-apis/) for an example on how to protect various Nakama APIs.

Sagi-shi players can delete groups which they are superadmins for:

```gdscript
await client.delete_group_async(session, "<group_id>")
```


### Group metadata

Like Users Accounts, Groups can have public metadata.

Sagi-shi uses group metadata to store the group's interests, active player times and languages spoken.

Group metadata can only be updated on the server. See the [updating group metadata](../../client-libraries/snippets/group-metadata) recipe for an example.

The Sagi-shi client makes an RPC with the group metadata payload:

```gdscript
var payload = {
    group_id = "<group_id>",
    interests = ["Deception", "Sabotage", "Cute Furry Bunnies"],
    active_times = ["9am-2pm Weekdays", "9am-10pm Weekends"],
    languages = ["English", "German"],
}

var result : NakamaAsyncResult = await client.rpc_async(session, "update_group_metadata", JSON.stringify(payload))
if result.is_exception():
    print("An error occurred: %s" % result)
    return
print("Successfully updated group metadata")
```


### Group membership states

Nakama group memberships are categorized with the following [states](../../concepts/groups/#groups-and-clans):

| Code | Purpose | |
| ---- | ------- | - |
|    0 | Superadmin | There must at least be 1 superadmin in any group. The superadmin has all the privileges of the admin and can additionally delete the group and promote admin members. |
|    1 | Admin | There can be one of more admins. Admins can update groups as well as accept, kick, promote, demote, ban or add members. |
|    2 | Member | Regular group member. They cannot accept join requests from new users. |
|    3 | Join request | A new join request from a new user. This does not count towards the maximum group member count. |


### Joining a group

If a player joins a public group they immediately become a member, but if they try and join a private group they must be accepted by a group admin.

Sagi-shi players can join a group:

```gdscript
await client.join_group_async(session, "<group_id>")
```


### Listing the user's groups

Sagi-shi players can list groups they are a member of:

```gdscript
var user_id = "<user id>"
var result : NakamaAPI.ApiUserGroupList = await client.list_user_groups_async(session, user_id)

for ug in result.user_groups:
    var g = ug.group as NakamaAPI.ApiGroup
    print("Group %s role %s", g.id, ug.state)
```


### Listing members

Sagi-shi players can list a group's members:

```gdscript
var group_id = "<group id>"
var member_list : NakamaAPI.ApiGroupUserList = await client.list_group_users_async(session, group_id)

for ug in member_list.group_users:
    var u = ug.user as NakamaAPI.ApiUser
    print("User %s role %s" % [u.id, ug.state])
```


### Accepting join requests

Private group admins or superadmins can accept join requests by re-adding the user to the group.

Sagi-shi first lists all the users with a join request state and then loops over and adds them to the group:

```gdscript
var result : NakamaAPI.ApiGroupUserList = await client.list_group_users_async(session, "<group_id>", 3)

for gu in result.group_users:
    var u = gu.user as NakamaAPI.ApiUser
    await client.add_group_users_async(session, "<group_id>", u)
```


### Promoting members

Nakama group members can be promoted to admin or superadmin roles to help manage a growing group or take over if members leave.

Admins can promote other members to admins, and superadmins can promote other members up to superadmins.

The members will be promoted up one level. For example:

- Promoting a member will make them an admin
- Promoting an admin will make them a superadmin

```gdscript
await client.promote_group_users_async(session, "<group_id>", "<user_id>")
```


### Demoting members

Sagi-shi group admins and superadmins can demote members:

```gdscript
await client.demote_group_users_async(session, "<group_id>", "<user_id>")
```


### Kicking members

Sagi-shi group admins and superadmins can remove group members:

```gdscript
await client.kick_group_users_async(session, "<group_id>", "<user_id>")
```


### Banning members

Sagi-shi group admins and superadmins can ban a user when demoting or kicking is not severe enough:

```gdscript
await client.ban_group_users_async(session, "<group_id>", "<user_id>")
```

### Leaving groups

Sagi-shi players can leave a group:

```gdscript
await client.leave_group_async(session, "<group_id>")
```


## Chat

Nakama Chat is a real-time chat system for groups, private/direct messages and dynamic chat rooms.

Sagi-shi uses dynamic chat during matches, for players to mislead each other and discuss who the imposters are, group chat and private/direct messages.

<figure>
  <img src={{< fingerprint_image "/images/pages/nakama/client-libraries/chat.png" >}} alt="Sagi-shi chat screen">
  <figcaption>Sagi-shi Chat</figcaption>
</figure>


### Joining dynamic rooms

Sagi-shi matches have a non-persistent chat room for players to communicate in:

```gdscript
var roomname = "<match_id>"
var persistence = false
var hidden = false
var type = NakamaSocket.ChannelType.Room
var channel : NakamaRTAPI.Channel = await socket.join_chat_async(roomname, type, persistence, hidden)

print("Connected to dynamic room channel: '%s'" % [channel.id])
```


### Joining group chat

Sagi-shi group members can have conversations that span play sessions in a persistent group chat channel:

```gdscript
var group_id = "<group_id>"
var persistence = true
var hidden = false
var type = NakamaSocket.ChannelType.Group
var channel : NakamaRTAPI.Channel = await socket.join_chat_async(group_id, type, persistence, hidden)

print("Connected to group channel: '%s'" % [channel.id])
```


### Joining direct chat

Sagi-shi players can also chat privately one-to-one during or after matches and view past messages:

```gdscript
var user_id = "<user_id>"
var persistence = true
var hidden = false
var type = NakamaSocket.ChannelType.DirectMessage
var channel : NakamaRTAPI.Channel = await socket.join_chat_async(user_id, type, persistence, hidden)

print("Connected to direct message channel: '%s'" % [channel.id])
```


### Sending messages

Sending messages is the same for every type of chat channel. Messages contain chat text and emotes and are sent as JSON serialized data:

```gdscript
var channel_id = "<channel_id>"

var message_content = { "message": "I think Red is the imposter!" }

var message_ack : NakamaRTAPI.ChannelMessageAck = await socket.write_chat_message_async(channel_id, message_content)

var emote_content = {
    "emote": "point",
    "emoteTarget": "<red_player_user_id>",
    }

var emote_ack : NakamaRTAPI.ChannelMessageAck = await socket.write_chat_message_async(channel_id, emote_content)
```


### Listing message history

Message listing takes a parameter which indicates if messages are received from oldest to newest (forward) or newest to oldest.

Sagi-shi players can list a group's message history:

```gdscript
var limit = 100
var forward = true
var group_id = "<group_id>"
var result : NakamaAPI.ApiChannelMessageList = await client.list_channel_messages_async(session, group_id, limit, forward)

for m in result.messages:
    var message : NakamaAPI.ApiChannelMessage = m as NakamaAPI.ApiChannelMessage
    print(message.user_id, message.content)
```

Chat also has cacheable cursors to fetch the most recent messages. Read more about cacheable cursors in the [listing notifications](../../concepts/notifications/#list-notifications) documentation.


### Updating messages

Nakama also supports updating messages. It is up to you whether you want to use this feature, but in a game like Sagi-shi it can add an extra element of deception.

For example a player sends the following message:

```gdscript
var channel_id = "<channel_id>"
var message_content = {"message": "I think Red is the imposter!" }

var message_ack : NakamaRTAPI.ChannelMessageAck = await socket.write_chat_message_async(channel_id, message_content)
```

They then quickly edit their message to confuse others:

```gdscript
var new_message_content = { "message": "I think BLUE is the imposter!" }

var message_update_ack : NakamaRTAPI.ChannelMessageAck = await socket.update_chat_message_async(channel_id, new_message_content)
```


## Matches

Nakama supports [Server Authoritative](../../concepts/multiplayer/authoritative/) and [Server Relayed](../../concepts/multiplayer/relayed/) multiplayer matches.

In server authoritative matches the server controls the gameplay loop and must keep all clients up to date with the current state of the game.

In server relayed matches the client is in control, with the server only relaying information to the other connected clients.

In a competitive game such as Sagi-shi, server authoritative matches would likely be used to prevent clients from interacting with your game in unauthorized ways.

For the simplicity of this guide, the server relayed model is used.


### Creating matches

Sagi-shi players can create their own matches and invite their online friends to join:

```gdscript
var match : NakamaRTAPI.Match = await socket.create_match_async()
var friends_list = await client.list_friends_async(session, 0, 100)
var online_friends = []
for friend in friends_list:
    var f = friend as NakamaAPI.ApiFriend
	if not f or not f.user.online:
		continue
    online_friends.append(f.user)

for f in online_friends:
    var content = {
        "message": "Hey %s, join me for a match!",
        match_id = match.id,
    }
    var channel = await socket.join_chat_async(f.id, NakamaSocket.ChannelType.DirectMessage)
    var message_ack = await socket.write_chat_message_async(channel.id, content)
``

**Creating a match by match name**

Sagi-shi players can also create matches with a specific match name, this allows them to invite their friends by telling them the name of the match. It should be noted that when creating a match by name (which is an arbitrary name and not something tied to authoritative match handlers), the match will always be a relayed match rather than an authoritative match.

```gdscript
var match_name = "NoImpostersAllowed"
var match : NakamaRTAPI.Match = await socket.create_match_async(match_name)
```

### Joining matches

Sagi-shi players can try to join existing matches if they know the id:

```gdscript
var match_id = "<matchid>"
var match = await socket.join_match_async(match_id)
```

Or set up a real-time matchmaker listener and add themselves to the matchmaker:

```gdscript
func _on_matchmaker_matched(p_matched : NakamaRTAPI.MatchmakerMatched):
  var match : NakamaRTAPI.Match = await socket.join_match_async(p_matched)

var min_players = 2
var max_players = 10
var query = ""

var matchmaking_ticket : NakamaRTAPI.MatchmakerTicket = await socket.add_matchmaker_async(query, min_players, max_players)
```


**Joining matches from player status**

Sagi-shi players can update their status when they join a new match:

```gdscript
var status = {
    "status": "Playing a match",
    "matchid": "<match_id>",
    }

await socket.update_status_async(status)
```

When their followers receive the real-time status event they can try and join the match:

```gdscript
func _on_status_presence(p_presence : NakamaRTAPI.StatusPresenceEvent):
    # Join the first match found in a friend's status
    for j in p_presence.joins:
        var status = JSON.parse_string(p_presence.status)
        if matchid in status:
            await socket.join_match_async(status["matchid"])
```

### Listing matches

[Match Listing](../../concepts/multiplayer/match-listing/) takes a number of criteria to filter matches by including player count, a match label and an option to provide a more complex [search query](../../concepts/multiplayer/query-syntax/).

Sagi-shi matches start in a lobby state. The match exists on the server but the actual gameplay doesn't start until enough players have joined.

Sagi-shi can then list matches that are waiting for more players:

```gdscript
var min_players = 2
var max_players = 10
var limit = 10
var authoritative = true
var label = ""
var query = ""
var result : NakamaRTApi.Match = await client.list_matches_async(session, min_players, max_players, limit, authoritative, label, query)

for m in result.matches:
    print("%s: %s/10 players", match.match_id, match.size)
```

To find a match that has a label of `"an_exact_match_label"`:

```gdscript
var label = "an_exact_match_label"
```

**Advanced:**

In order to use a more complex structured query, the match label must be in JSON format.

To find a match where it expects player skill level to be `>100` and optionally has a game mode of `"sabotage"`:

```gdscript
var query = "+label.skill:>100 label.mode:sabotage"
```


### Spawning players

The match object has a list of current online users, known as presences.

Sagi-shi uses the match presences to spawn players on the client:

```gdscript
var match = await socket.join_match_async(match_id)

var players = {}

for p in match.presences:
    // Spawn a player for this presence and store it in a dictionary by session id.
    var go = <player_node>.new()
    players.add(presence.session_id, go)
```

Sagi-shi keeps the spawned players up-to-date as they leave and join the match using the match presence received event:

```gdscript
func _on_match_presence(p_presence : NakamaRTApi.MatchPresenceEvent):
    # For each player that has joined in this event...
    for p in p_presence.joins:
        # Spawn a player for this presence and store it in a dictionary by session id.
        var go = <player_node>.new()
        players.add(p_presence.session_id, go)
    # For each player that has left in this event...
    for p in p_presence.leaves:
        # Remove the player from the game if they've been spawned
        if presence.session_id in players:
            <player_node>.remove_and_skip()
            players.remove(presence.session_id)
```

### Sending match state

Nakama has real-time networking to [send](../../concepts/multiplayer/relayed/#send-data-messages) and [receive](../../concepts/multiplayer/relayed/#receive-data-messages) match state as players move and interact with the game world.

During the match, each Sagi-shi client sends match state to the server to be relayed to the other clients.

Match state contains an op code that lets the receiver know what data is being received so they can deserialize it and update their view of the game.

Example op codes used in Sagi-shi:
- 1: player position
- 2: player calling vote


**Sending player position**

Define a class to represent Sagi-shi player position states:

```gdscript
class_name position_state

var X
var Y
var Z
```

Create an instance from the player's transform, set the op code and send the JSON encoded state:

```gdscript
var state = {
    X = transform.x,
    Y = transform.y,
    Z = transform.z,
}

var op_code = 1

await socket.send_match_state_async(match.id, op_code, JSON.stringify(state))
```


**Op Codes as a static class**

Sagi-shi has many networked game actions. Using a static class of constants for op codes will keep your code easier to follow and maintain:

```gdscript
class_name op_codes

const position = 1
const vote = 2

await socket.send_match_state_async(match.id, op_codes.position, JSON.stringify(state))
```


### Receiving match state

Sagi-shi players can receive match data from the other connected clients by subscribing to the match state received event:

```gdscript
socket.received_match_state.connect(self._on_match_state)

func _on_match_state(match_state : NakamaRTAPI.MatchData):
    match match_state.op_code:
        op_code.position:
            # Get the updated position data
            var position_state = JSON.parse_string(match_state.data)
            # Update the game object associated with that player
            var user = match_state.user_presence.session_id
            if user in players:
                # Here we would normally do something like smoothly interpolate to the new position, but for this example let's just set the position directly.
                players[user].transform.Vector3 = vec(position_state.x, position_state.y, position_state.z)
        _:
            print("Unsupported op code.")

```


## Matchmaker

Developers can find matches for players using Match Listing or the Nakama [Matchmaker](../../concepts/multiplayer/matchmaker/), which enables players join the real-time matchmaking pool and be notified when they are matched with other players that match their specified criteria.

Matchmaking helps players find each other, it does not create a match. This decoupling is by design, allowing you to use matchmaking for more than finding a game match. For example, if you were building a social experience you could use matchmaking to find others to chat with.


### Add matchmaker

Matchmaking criteria can be simple, find 2 players, or more complex, find 2-10 players with a minimum skill level interested in a specific game mode.

Sagi-shi allows players to join the matchmaking pool and have the server match them with other players:

```gdscript
var min_players = 2
var max_players = 10
var query = "+skill:>100 mode:sabotage"
var string_properties = { "mode": "sabotage" }
var numeric_properties = { "skill": 125 }
var matchmaker_ticket : NakamaRTAPI.MatchmakerTicket = await socket.add_matchmaker_async(query, min_players, max_players, string_properties, numeric_properties)
```

After being successfully matched according to the provided criteria, players can join the match:

```gdscript
func _on_matchmaker_matched(p_matched : NakamaRTAPI.MatchmakerMatched):
  var joined_match : NakamaRTAPI.Match = await socket.join_match_async(p_matched)
```

## Parties

Nakama [Parties](../../concepts/parties/) is a real-time system that allows players to form short lived parties that don't persist after all players have disconnected.

Sagi-shi allows friends to form a party and matchmake together.


### Creating parties

The player who creates the party is the party's leader. Parties have maximum number of players and can be open to automatically accept players or closed so that the party leader can accept incoming join requests.

Sagi-shi uses closed parties with a maximum of 4 players:

```gdscript
var open = false
var max_players = 4
var party = await socket.create_party_async(open, max_players)
```

Sagi-shi shares party ids with friends via private/direct messages:

```gdscript
var friends_list : NakamaAPI.ApiFriendList = await client.list_friends_async(session, limit, friendship_state)
var online_friends = []
for friend in friends_list:
    var f = friend as NakamaAPI.ApiFriend
    if not f or not f.user.online:
        continue
    online_friends.append(f.user)

for f in online_friends:
    var content = {
        "message": "Hey %s, wanna join the party?",
        party_id = party.id,
    }
    var channel = await socket.join_chat_async(f.id, NakamaSocket.ChannelType.DirectMessage)
    var message_ack = await socket.write_chat_message_async(channel.id, content)
```


### Joining parties

Safi-shi players can join parties from chat messages by checking for the party id in the message.
First the socket's `received_channel_message` signal must be connected.

```gdscript
socket.received_channel_message.connect(self._on_received_channel_message)
```

Then, when that signal is received, the message contents can be checked and the party can be joined.

```gdscript
func _on_received_channel_message(message):
    var data = JSON.parse_string(message.content)
    if data.result.party_id:
        var join = await socket.join_party_async(data.result.party_id)
        if join.is_exception():
            print("error joining party)
```


### Promoting a member

Sagi-shi party members can be promoted to the party leader:

```gdscript
var new_leader = "<user_id>"
var party_id = "<party_id>"
var leader: NakamaAsyncResult = await socket.received_party_leader(party_id, new_leader)
```

### Leaving parties

Sagi-shi players can leave parties:

```gdscript
var party_id = "<party_id>"
var party: NakamaAsyncResult = await socket.leave_party_async(party_id)
```


### Matchmaking with parties

One of the main benefits of joining a party is that all the players can join the matchmaking pool together.

Sagi-shi players can listen to the the matchmaker matched event and join the match when one is found:

```gdscript
func _on_matchmaker_matched(p_matched : NakamaRTAPI.MatchmakerMatched):
  var joined_match : NakamaRTAPI.Match = await socket.join_match_async(p_matched)
```

The party leader will start the matchmaking for their party:

```gdscript
var party_id = "<party_id>"
var min_players = 2
var max_players = 10
var query = ""
var matchmaker_ticket = await socket.add_matchmaker_party_async(party_id, query, min_players, max_players)
```


### Sending party data

Sagi-shi players can send data to other members of their party to indicate they wish to start a vote.

```gdscript
var state = {
    username = "<Username>",
    reason = "Emergency
}

var vote_op_code = 6
await socket.send_party_state_async(party.id, op_code, JSON.stringify(state))
```


### Receiving party data

Sagi-shi players can receive party data from other party members by subscribing to the party data event.

```gdscript
socket.received_party_data.connect(self._on_party_data)

func _on_party_data(party_data : NakamaRTAPI.PartyData):
    match party_data.op_code:
        vote_op_code:
            var vote_state = JSON.parse_string(party_data.data)
            # Show a UI dialogue - "<username> has proposed to call a vote for <reason>. Do you agree? Yes/No"
```


## Leaderboards

Nakama [Leaderboards](../../concepts/leaderboards/) introduce a competitive aspect to your game and increase player engagement and retention.

Sagi-shi has a leaderboard of weekly imposter wins, where player scores increase each time they win, and similarly a leaderboard for weekly crew member wins.

<figure>
  <img src={{< fingerprint_image "/images/pages/nakama/client-libraries/leaderboard.png" >}} alt="Sagi-shi leaderboard screen">
  <figcaption>Sagi-shi Leaderboard</figcaption>
</figure>


### Creating leaderboards

Leaderboards have to be created on the server, see the [leaderboard](../../concepts/leaderboards/#create-a-leaderboard) documentation for details on creating leaderboards.


### Submitting scores

When players submit scores, Nakama will increment the player's existing score by the submitted score value.

Along with the score value, Nakama also has a subscore, which can be used for ordering when the scores are the same.

Sagi-shi players can submit scores to the leaderboard with contextual metadata, like the map the score was achieved on:

```gdscript
var score = 1
var subscore = 0
var metadata = { "map": "space_station" }
var record : NakamaAPI.ApiLeaderboardRecord = await client.write_leaderboard_record_async(session, "weekly_imposter_wins", score, subscore, JSON.stringify(metadata))
```

### Listing the top records

Sagi-shi players can list the top records of the leaderboard:

```gdscript
var limit = 20
var leaderboard_name = "weekly_imposter_wins"
var result : NakamaAPI.ApiLeaderboardRecordList = await client.list_leaderboard_records_async(session, leaderboard_name, null, null, limit, null)

for r in result.records:
    print("%s:%s", record.owner_id, record.score)
```


**Listing records around the user**

Nakama allows developers to list leaderboard records around a player.

Sagi-shi gives players a snapshot of how they are doing against players around them:

```gdscript
var limit = 5
var leaderboard_name = "weekly_imposter_wins"
var result : NakamaAPI.ApiLeaderboardRecordList = await client.list_leaderboard_records_async(session, leaderboard_name, session.user_id, null, limit)

for r in result.records:
    print("%s:%s", record.owner_id, record.score)
```

For example, if the leaderboard contains 100 records and the ownerId = "player123" with limit = 5, the result will include the specified user along with nearby records:

```json
{
  "records": [
    { "ownerId": "player120", "rank": 48, "score": 1500 },
    { "ownerId": "player121", "rank": 49, "score": 1480 },
    { "ownerId": "player123", "rank": 50, "score": 1450 },  // Your ownerId
    { "ownerId": "player125", "rank": 51, "score": 1430 },
    { "ownerId": "player127", "rank": 52, "score": 1400 }
  ]
}
```


**Listing records for a list of users**

Sagi-shi players can get their friends' scores by supplying their user ids to the owner id parameter:

```gdscript
var friends_list : NakamaAPI.ApiFriendList = await client.list_friends_async(session, 0, 100, cursor: null)
var user_ids = []
for friend in friends_list.friends:
    var f = friend as NakamaAPI.ApiFriend
    user_ids.append(f.user.id)

var record_list : NakamaAPI.ApiLeaderboardRecordList = await client.list_leaderboard_records_around_owner_async(session, "weekly_imposter_wins", user_ids, null, 100, null)

for record in record_list.records:
    print("%s scored %s", record.username, record.score)
```

The same approach can be used to get group member's scores by supplying their user ids to the owner id parameter:

```gdscript
var group_id = "<groupid>"
var group_user_list : NakamaAPI.ApiGroupUserList = await client.list_group_users_async(session, group_id, 100, null)
var user_ids = []
for gu in group_user_list.group_users:
    var u = gu as NakamaAPI.ApiUser
    user_ids.append(u.user.id)

var record_list : NakamaAPI.ApiLeaderboardRecordList = await client.list_leaderboard_records_around_owner_async(session, "weekly_imposter_wins", user_ids, null, 100, null)
```


### Deleting records

Sagi-shi players can delete their own leaderboard records:

```gdscript
await client.delete_leaderboard_record_async(session, "<leaderboard_id>")
```


## Tournaments

Nakama [Tournaments](../../concepts/tournaments/) are short lived competitions where players compete for a prize.

Sagi-shi players can view, filter and join running tournaments.

<figure>
  <img src={{< fingerprint_image "/images/pages/nakama/client-libraries/tournaments.png" >}} alt="Sagi-shi tournaments screen">
  <figcaption>Sagi-shi Tournaments</figcaption>
</figure>


### Creating tournaments

Tournaments have to be created on the server, see the [tournament](../../concepts/tournaments/#create-tournament) documentation for details on how to create a tournament.

Sagis-shi has a weekly tournament which challenges players to get the most correct imposter votes. At the end of the week the top players receive a prize of in-game currency.


### Joining tournaments

By default in Nakama players don't have to join tournaments before they can submit a score, but Sagi-shi makes this mandatory:

```gdscript
await client.join_tournament_async(session, "<id>")
```

### Listing tournaments

Sagi-shi players can list and filter tournaments with various criteria:

```gdscript
var category_start = 1
var category_end = 2
int start_time = null
int end_time = null
var limit = 100
var result : NakamaAPI.ApiTournamentRecordList = await client.list_tournament_records_async(session, category_start, category_end, start_time, end_time, limit, null)

for t in result.tournaments:
    print("%s:%s", tournament.id, tournament.title)
```

Categories are filtered using a range, not individual numbers, for performance reasons. Structure your categories to take advantage of this (e.g. all PvE tournaments in the 1XX range, all PvP tournaments in the 2XX range, etc.).


### Listing records

Sagi-shi players can list tournament records:

```gdscript
var limit = 20
var tournament_name = "weekly_top_detective"
var result : NakamaAPI.ApiTournamentRecordList = await client.list_tournament_records_async(session, tournament_name, null, null, limit, null)

for r in result.records:
    print("%s:%s", record.owner_id, record.score)
```


**Listing records around a user**

Similarly to leaderboards, Sagi-shi players can get other player scores around them:

```gdscript
var limit = 20
var tournament_name = "weekly_top_detective"
var result : NakamaAPI.ApiTournamentRecordList = await client.list_tournament_records_async(session, tournament_name, session.user_id, null, limit)

for r in result.records:
    print("%s:%s", record.owner_id, record.score)
```


### Submitting scores

Sagi-shi players can submit scores, subscores and metadata to the tournament:

```gdscript
var score = 1
var subscore = 0
var metadata = JSON.stringify({
    "map": "space_station" })
var new_record : NakamaAPI.ApiLeaderboardRecord = await client.write_tournament_record_async(session, "weekly_top_detective", score, subscore, metadata)
```


## Notifications

Nakama [Notifications](../../concepts/notifications/) can be used for the game backend to broadcast real-time messages to players.

Notifications can be either persistent (remaining until a player has viewed it) or transient (received only if the player is currently online).

Sagi-shi uses Notifications to notify tournament winners about their winnings.

<figure>
  <img src={{< fingerprint_image "/images/pages/nakama/client-libraries/notifications.png" >}} alt="Sagi-shi notification screen">
  <figcaption>Sagi-shi notifications</figcaption>
</figure>


### Receiving notifications

Notifications have to be sent from the server.

Nakama uses a code to differentiate notifications. Codes of `0` and below are [system reserved](../../concepts/notifications/#notification-codes) for Nakama internals.

Sagi-shi players can subscribe to the notification received event. Sagi-shi uses a code of `100` for tournament winnings:

```gdscript
cont reward_code = 100

func _on_notification(p_notification : NakamaAPI.ApiNotification):
    match notification.code:
        reward_code:
            print("Congratulations, you won the tournament!\n%s\n%s", notification.subject, notification.content)
        _:
            print("Other notification: %s:%s\n%s", notification.code, notification.subject, notification.content)
```


### Listing notifications

Sagi-shi players can list the notifications they received while offline:

```gdscript
var limit = 100
var result : NakamaAPI.ApiNotificationList = await client.list_notifications_async(session, limit)

for n in result.notifications:
    print("Notification: %s:{%s\n%s", notification.code, notification.subject, notification.content)
```


**Pagination and cacheable cursors**

Like other listing methods, notification results can be paginated using a cursor or cacheable cursor from the result.

```gdscript
var result : NakamaAPI.ApiNotificationList = await client.list_notifications_async(session, 1)
var cacheable_cursor = result.cacheable_cursor
```

The next time the player logs in the cacheable cursor can be used to list unread notifications.

```gdscript
var next_results = await client.list_notifications_async(session, limit, cacheable_cursor)
```


### Deleting notifications

Sagi-shi players can delete notifications once they've read them:

```gdscript
var notification_ids = ["<notification-id>"]
var delete : NakamaAsyncResult = await client.delete_notifications_async(session, notification_ids)
```
