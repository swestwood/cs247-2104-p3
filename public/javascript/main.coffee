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
    @fb_quiz_stream = @fb_new_chat_room.child('quiz')


class window.Quiz
  """Builds and renders a single quiz."""

  constructor: (@emoticonAnswer, @videoData, @fromUser, @toUser, @elem) ->
    @videoBlob = URL.createObjectURL(BlobConverter.base64_to_blob(videoData))
    @wrongAnswers = []

  render: =>
    context =
      videoUrl: @videoBlob
      fromUser: @fromUser
      # userColor: @userColor
      emoticon: @emoticonAnswer
      quizChoices: @makeQuizChoices(@emoticonAnswer)
    html = window.Templates["quiz"](context)
    @elem.html(html)

  makeQuizChoices: (actualEmoticon) =>
    """Creates a list of emoticon quiz choices, where the other emoticon choices do not express the
    same emotion as the actual emoticon, or the same emotion as each other."""
    @wrongChoices = EmotionProcessor.chooseEmotionsExcept(actualEmoticon, NUMBER_WRONG_CHOICES)
    allChoices = _.clone(@wrongChoices)
    allChoices.push(actualEmoticon)
    allChoices = _.shuffle(allChoices)
    choiceContext = ({"emoticon": choice, "correct": if choice == actualEmoticon then "correct" else "wrong"} for choice in allChoices)
    return choiceContext


class window.QuizCoordinator
  """Manipulates Quiz objects for the game."""

  constructor: (@elem) ->
    @quizProbability = 1
    @currentQuiz = null  # Non-null if a quiz is currently being taken by the user
    @username = null  # Should be set by the chatroom as soon as a username is given.

  respondToAnswerChoice: (evt) =>
    return if @currentQuiz == null
    isCorrect = $(evt.target).hasClass("correct")
    if isCorrect
      $("#quiz_container").css({"background-color": "green"})
    else
      $("#quiz_container").css({"background-color": "#FFCCCC"})
    @currentQuiz = null  # A choice was made, so we are ready for another quiz. TODO set a time so it isn't given too soon..
    @elem.addClass("inactive").removeClass("active")

  setUserName: (user) =>
    @username = user

  giveQuiz: (msg) =>
    # TODO modify based on probability. Don't do the face game with multiple emoticons
    return EmotionProcessor.countEmoticons(msg) == 1

  handleIncomingQuiz: (snapshot) =>
    console.log "handling incoming quiz"
    if @currentQuiz != null # or snapshot.username == @username  # TODO put back in so user doesn't see own quiz
      return  # Ignore the quiz if there is already a quiz taken by this user, or if the quiz came from this user.
    console.log("new quiz!")
    $("#quiz_container").css({"background-color": "lightgray"})
    console.log snapshot
    @currentQuiz = new Quiz(snapshot.emoticon, snapshot.v, snapshot.fromUser, @username, @elem)
    @elem.addClass("active").removeClass("inactive")
    @currentQuiz.render()
    $(".quiz-choice").one("click", @respondToAnswerChoice)  # Only listens for one click, then no more.


class window.ChatRoom
  """Main class to control the chat room UI of messages and video"""
  constructor: (@fbInteractor, @videoRecorder) ->
    @quizCoordinator = new QuizCoordinator($("#quiz_container"))

    # Listen to Firebase events
    @fbInteractor.fb_instance_users.on "child_added", (snapshot) =>
      @displayMessage({m: snapshot.val().name + " joined the room", c: snapshot.val().c})

    @fbInteractor.fb_instance_stream.on "child_added", (snapshot) =>
      @displayMessage(snapshot.val())

    @fbInteractor.fb_quiz_stream.on "child_added", (snapshot) =>
      @quizCoordinator.handleIncomingQuiz(snapshot.val())

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
      if (event.which == 13)  # ENTER
        message = @submissionEl.val()
        console.log(message)
        console.log(EmotionProcessor.getEmoticon(message))
        if @quizCoordinator.giveQuiz(message)
          console.log "doing quiz"
          [redactedMessage, _] = EmotionProcessor.redactEmoticons(message)
          @fbInteractor.fb_instance_stream.push
            m: @username + ": " + redactedMessage  # Send the message with smiley redacted
            c: @userColor
          @fbInteractor.fb_quiz_stream.push
            fromUser: @username
            c: @userColor
            v: @videoRecorder.curVideoBlob
            emoticon: EmotionProcessor.getEmoticon(message)
        else
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



