# Initial code by Borui Wang, updated by Graham Roth,
# refactored and converted to Coffeescript by Sophia Westwood.
#
# Compile by running coffee -wc *.coffee to generate main.js and compile other .coffee files in the directory.
# For CS247, Spring 2014

# Drawn from http://en.wikipedia.org/wiki/List_of_emoticons

window.EMOTICON_MAP =
  "angry": [">:(", ">_<"]  # Sort roughly so that the full emoticon is captured, ie ">:(" does not first match ":("
  "crying": [":'-(", ":'("]
  "surprise": [">:O", ":-O", ":O", ":-o", ":o", "8-0", "O_O", "o-o", "O_o", "o_O", "o_o", "O-O"]
  "tongue": [">:P", ":-P", ":P", "X-P", "x-p", "xp", "XP", ":-p", ":p", "=p", ":-b", ":b", "d:"]
  "laughing": [":-D", ":D", "8-D", "8D", "x-D", "xD", "X-D", "XD", "=-D", "=D", "=-3", "=3"]
  "happy": [":-)", ":)", ":o)", ":]", ":3", ":c)", ":>", "=]", "8)", "=)", ":}"]
  "sad": [">:[", ":-(", ":(", ":-c", ":c", ":-<", ":<", ":-[", ":[", ":{"]
  "wink": [";-)", ";)", "*-)", "*)", ";-]", ";]", ";D", ";^)", ":-,"]
  "uneasy": [">:\\", ">:/", ":-/", ":-.", ":/", ":\\", "=/", "=\\", ":L", "=L", ":S", ">.<"]
  "expressionless": [":|", ":-|"]
  "embarrassed": [":$"]
  "secretive": [":-X", ":X"]
  "heart": ["<3"]
  "broken": ["</3"]

window.VIDEO_LENGTH_MS = 1000  # The length of time that the snippets are recorded

window.NUMBER_WRONG_CHOICES = 3  # The number of wrong choices shown for a quiz

window.MIN_REQUIRED_VIDEOS_FOR_QUIZ = 1

class window.FirebaseInteractor
  """Connects to Firebase and connects to chatroom variables."""
  constructor: ->
    @fb_instance = new Firebase("https://proto1-cs247-p3-fb.firebaseio.com")

  # generate new chatroom id or use existing id
  get_fb_chat_room_id: =>
      url_segments = document.location.href.split("/#")
      if url_segments[1]
        return url_segments[1]
      return Math.random().toString(36).substring(7)

  init: =>
    # set up variables to access firebase data structure
    @fb_chat_room_id = @get_fb_chat_room_id()
    @fb_new_chat_room = @fb_instance.child('chatrooms').child(@fb_chat_room_id)
    @fb_instance_users = @fb_new_chat_room.child('users')
    @fb_instance_stream = @fb_new_chat_room.child('stream')
    @fb_user_video_list = @fb_new_chat_room.child('user_video_list')
    @fb_user_quiz_one = @fb_new_chat_room.child('user_quiz_one')

class window.Quiz
  """Builds and renders a single quiz."""

  constructor: (@emoticonAnswer, @choices, @videoData, @fromUser, @toUser, @elem, @status) ->
    @videoBlob = URL.createObjectURL(BlobConverter.base64_to_blob(videoData))

  render: =>
    context =
      videoUrl: @videoBlob
      fromUser: @fromUser
      # userColor: @userColor
      emoticon: @emoticonAnswer
      quizChoices: @choices
    html = window.Templates["quiz"](context)
    @elem.html(html)


class window.QuizCoordinator
  """Manipulates Quiz objects for the game."""

  constructor: (@elem, @emotionVideoStore, @fbInteractor) ->
    @quizProbability = 1
    # @currentQuiz = null  # Non-null if a quiz is currently being taken by the user
    @username = null  # Should be set by the chatroom as soon as a username is given.

  respondToAnswerChoice: (evt) =>
    $("#quiz_container .quiz-choice").off("click", @respondToAnswerChoice)  # Only listen once.
    # return if @currentQuiz == null
    isCorrect = $(evt.target).hasClass("correct")
    console.log $(evt.target).html()
    @fbInteractor.fb_user_quiz_one.update({"status": "new guess", "guess": $(evt.target).html(), "guessCorrect": isCorrect})

  handleGuessMade: (snapshot) =>
    if snapshot.guessCorrect
      $("#quiz_container").css({"background-color": "green"})
    else
      $("#quiz_container").css({"background-color": "#FFCCCC"})
    @elem.addClass("inactive").removeClass("active")
    @fbInteractor.fb_user_quiz_one.update({"status": "quiz over"})

  setUserName: (user) =>
    @username = user

  handleIncomingQuiz: (snapshot) =>
    console.log "handling incoming quiz"
    $("#quiz_container").css({"background-color": "lightgray"})
    quiz = new Quiz(snapshot.emoticon, snapshot.choices, snapshot.v, snapshot.fromUser, @username, @elem, snapshot.status)
    quiz.render()
    $("#quiz_container").addClass("active").removeClass("inactive")
    if snapshot.fromUser == @username
      $("#quiz_container").removeClass("enabled")
      $("#quiz_container").css({"background-color": "lightgray"})
    else
      $("#quiz_container").addClass("enabled")
      $("#quiz_container").css({"background-color": "lightblue"})
      $("#quiz_container .quiz-choice").on("click", @respondToAnswerChoice)  # Only listens for one click, then no more.

  getLongVideoArrays: =>
    longVideoArrs = {}
    for key, val of @emotionVideoStore.videos
      console.log "this hsould be a user name also " + key
      if _.size(val) >= MIN_REQUIRED_VIDEOS_FOR_QUIZ
        longVideoArrs[key] = val
    return longVideoArrs

  readyForQuiz: =>
    # Find the two longest user arrays in the video store. Check if they are longer than the min required.
    # If both are, then return true.
    enoughUserVideos = @getLongVideoArrays()
    return _.size(enoughUserVideos) >= 2

  responsibleForMakingQuiz: (enoughUserVideos) =>
    return _.every enoughUserVideos, (key, val) =>
      console.log "this hsould be a user name" + val
      return @username >= val

  createQuiz: =>
    enoughUserVideos = @getLongVideoArrays()
    if _.size(enoughUserVideos) < 2
      console.error "Trying to create a quiz, but without enough user videos!"
      return
    if _.size(enoughUserVideos) > 2
      console.error "There are more than 2 users, this is bad!"  # TODO maybe handle this better
    if not @responsibleForMakingQuiz(enoughUserVideos)
      console.log 'not responsible'
      return
    console.log 'responsible, making quiz'
    # This user is actually responsible for making the quiz
    # Choose a random video
    randomVideo = _.sample(enoughUserVideos[@username])  # TODO choose 2 videos
    # TODO remove the video from the firebase list of videos, and remove it from both clients too! listen to child_removed
    @fbInteractor.fb_user_quiz_one.set(randomVideo)



class window.EmotionVideoStore
  """Stores a map from each user to a list of that user's emotion videos"""

  constructor: ->
    @videos = {}

  addVideoSnapshot: (data) =>
    if data.fromUser not in @videos
      @videos[data.fromUser] = []
    @videos[data.fromUser].push(data)
    console.log "videos: "
    console.log @videos

class window.ChatRoom
  """Main class to control the chat room UI of messages and video"""
  constructor: (@fbInteractor, @videoRecorder) ->
    @emotionVideoStore = new EmotionVideoStore()
    @quizCoordinator = new QuizCoordinator($("#quiz_container"), @emotionVideoStore, @fbInteractor)

    # Listen to Firebase events
    @fbInteractor.fb_instance_users.on "child_added", (snapshot) =>
      @displayMessage({m: snapshot.val().name + " joined the room", c: snapshot.val().c})

    @fbInteractor.fb_instance_stream.on "child_added", (snapshot) =>
      @displayMessage(snapshot.val())

    @fbInteractor.fb_user_video_list.on "child_added", (snapshot) =>  # TODO listen to removed as well to update list
      @emotionVideoStore.addVideoSnapshot(snapshot.val())
      if @quizCoordinator.readyForQuiz()  # TODO move this so that it fires randomly.
        console.log "Ready for quiz!"
        @quizCoordinator.createQuiz()

    @fbInteractor.fb_user_quiz_one.on "value", (snapshot) =>
      console.log "snapshot"
      snapshotVal = snapshot.val()
      console.log snapshotVal
      if not snapshotVal
        return
      if snapshotVal.status == 'new quiz'
        @quizCoordinator.handleIncomingQuiz(snapshotVal)
      if snapshotVal.status == 'new guess'
        @quizCoordinator.handleGuessMade(snapshotVal)
      # Otherwise status is "quiz over"


    @submissionEl = $("#submission input")

  init: =>
    url = document.location.origin+"/#"+@fbInteractor.fb_chat_room_id
    @displayMessage({m: "Share this url with your friend to join this chat: <a href='" + url + "' target='_blank'>" + url+"</a>", c: "darkred"})
    # Block until user name entered
    # @username = window.prompt("Welcome! What's your name?")  # Commented out for faster testing.
    if not @username
      @username = "anonymous"+Math.floor(Math.random()*1111)
    @quizCoordinator.setUserName(@username)
    @userColor = "#"+((1<<24)*Math.random()|0).toString(16) # Choose random color

    @fbInteractor.fb_instance_users.push({ name: @username,c: @userColor})
    $("#waiting").remove()
    @setupSubmissionBox()

  setupSubmissionBox: =>
    # bind submission box
    $("#submission input").on "keydown", (event) =>
      if event.which == 13  # ENTER
        message = @submissionEl.val()
        console.log(message)
        emoticon = EmotionProcessor.getEmoticon(message)
        if emoticon
          @fbInteractor.fb_user_video_list.push
            fromUser: @username
            c: @userColor
            v: @videoRecorder.curVideoBlob
            emoticon: emoticon
            choices: EmotionProcessor.makeQuizChoices(emoticon)
            status: "new quiz"
          [message, _] = EmotionProcessor.redactEmoticons(message) # Send the message with smiley redacted
        @fbInteractor.fb_instance_stream.push
          m: @username + ": " + message
          c: @userColor
        @submissionEl.val("")

  scrollToBottom: (wait_time) =>
    # scroll to bottom of div
    setTimeout =>
      $("html, body").animate({ scrollTop: $(document).height() }, 200)
    , wait_time

  createVideoElem: (video_data) =>
    # for gif instead, use this code below and change mediaRecorder.mimeType in onMediaSuccess below
    # var video = document.createElement("img")
    # video.src = URL.createObjectURL(BlobConverter.base64_to_blob(data.v))

    # for video element
    video = document.createElement("video")
    video.autoplay = true
    video.controls = false # optional
    video.loop = true
    video.width = 120

    source = document.createElement("source")
    source.src =  URL.createObjectURL(BlobConverter.base64_to_blob(video_data))
    source.type =  "video/webm"
    return [source, video]

  # creates a message node and appends it to the conversation
  displayMessage: (data) =>
    $("#conversation").append("<div class='msg' style='color:"+data.c+"'>"+data.m+"</div>")
    if data.v
      [source, video] = @createVideoElem(data.v)
      video.appendChild(source)
      document.getElementById("conversation").appendChild(video)

      #Create copy of video node. TEMPORARY!!! TODO
      quiz_video = video.cloneNode(true);
      quiz_video.className += "vid_quiz"
      quiz_video.autoplay = true
      quiz_video.controls = false # optional
      quiz_video.loop = true
      quiz_video.width = 350
      document.getElementById("video_box").appendChild(quiz_video)
      #$("#quiz_mode").show();

    # Scroll to the bottom every time we display a new message
    @scrollToBottom(0);


# Start everything!
$(document).ready ->
  fbInteractor = new FirebaseInteractor()
  fbInteractor.init()
  videoRecorder = new VideoRecorder()
  chatRoom = new ChatRoom(fbInteractor, videoRecorder)
  chatRoom.init()
  videoRecorder.connectWebcam()



