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

window.VIDEO_LENGTH_MS = 4000  # The length of time that the snippets are recorded  # TODO make longer after testing

window.NUMBER_WRONG_CHOICES = 3  # The number of wrong choices shown for a quiz

window.MIN_REQUIRED_VIDEOS_FOR_QUIZ = 2

class window.FirebaseInteractor
  """Connects to Firebase and connects to chatroom variables."""
  constructor: ->
    @fb_instance = new Firebase("https://proto1-cs247-p3-fb.firebaseio.com")

  init: =>
    # set up variables to access firebase data structure
    @fb_chat_room_id = window.get_fb_chat_room_id()
    @fb_new_chat_room = @fb_instance.child('chatrooms').child(@fb_chat_room_id)
    @fb_instance_users = @fb_new_chat_room.child('users')
    @fb_instance_stream = @fb_new_chat_room.child('stream')
    @fb_user_video_list = @fb_new_chat_room.child('user_video_list')
    @fb_user_quiz_one = @fb_new_chat_room.child('user_quiz_one')
    @fb_user_quiz_two = @fb_new_chat_room.child('user_quiz_two')

class window.Powerup
  """Builds and renders a single powerup screen."""

  constructor: (@elem) ->
    # Do nothing

  render: =>
    context =
      numRequiredVideos: MIN_REQUIRED_VIDEOS_FOR_QUIZ
    html = window.Templates["powerup"](context)
    @elem.html(html)

class window.Quiz
  """Builds and renders a single quiz."""

  constructor: (@emoticonAnswer, @choices, @videoData, @fromUser, @toUser, @elem, @status, @currUser) ->
    @videoBlob = URL.createObjectURL(BlobConverter.base64_to_blob(videoData))

  render: =>
    videoOfCurrUser = @fromUser == @currUser
    message = "How well do you know " + @fromUser + "?"
    if videoOfCurrUser
      message = "How well do they know you?"
    context =
      videoUrl: @videoBlob
      fromUser: @fromUser
      # userColor: @userColor
      emoticon: @emoticonAnswer
      quizChoices: @choices
      challengeMessage: message
      forWhomClass: if videoOfCurrUser then "otherPersonGuessing" else "selfIsGuessing"
    html = window.Templates["quiz"](context)
    @elem.html(html)

class window.QuizCoordinator
  """Manipulates Quiz objects for the game."""

  constructor: (@elem, @emotionVideoStore, @fbInteractor, @currentPowerup, @updatePowerupScreenFcn, @quizIsShown) ->
    @quizProbability = 1
    # @currentQuiz = null  # Non-null if a quiz is currently being taken by the user
    @username = null  # Should be set by the chatroom as soon as a username is given.

  getQuizInteractor: (quizName) =>
    user_quiz_fb = if quizName == "quiz_one" then @fbInteractor.fb_user_quiz_one else @fbInteractor.fb_user_quiz_two
    console.log "user item"
    console.log user_quiz_fb
    return user_quiz_fb

  respondToAnswerChoice: (evt, quizChoiceSelector, quizName) =>
    # return if @currentQuiz == null
    $(quizChoiceSelector).off("click")  # Only listen once. TODO test
    isCorrect = $(evt.target).hasClass("correct")
    chosenFace = $(evt.target).html()
    @getQuizInteractor(quizName).update({"status": "new guess", "guess": $(evt.target).html(), "guessCorrect": isCorrect, "chosenFace": chosenFace})

  handleGuessMade: (snapshot, quizName) =>
    quizEl = $(@elem.find("." + quizName))
    if snapshot.guessCorrect
      quizEl.addClass("guessedCorrectly")
      quizEl.css({"background-color": "#5fb079"})
    else
      quizEl.addClass("guessedWrong")
      quizEl.css({"background-color": "#ee7e7e"})
      for choiceElem in quizEl.find(".quiz-choice")
        choiceElem = $(choiceElem)
        if choiceElem.html() == snapshot.chosenFace
          choiceElem.addClass("wrongChoiceThatWasGuessed")


    quizEl.addClass("inactive").removeClass("active")
    @getQuizInteractor(quizName).update({"status": "quiz over"})


    if $(".quiz.inactive").size() == 2  # TODO hacky -- basically if both quizzes are now inactive, they can end the quiz
      console.log "switching screens back to powerup"
      seconds = 7
      $("#quiz-done-area").show().html("Finished the quiz! Moving on in " + seconds + " seconds...")
      setTimeout =>
        $("#quiz-done-area").html("").hide()
        @switchScreen(false)
      , seconds*1000   # Show the powerup screen now.
      

  setUserName: (user) =>
    @username = user

  switchScreen: (showQuiz) =>
    if showQuiz
      @quizIsShown = true
      $('#quiz_container').show()
      $('#powerup_container').hide()
      $(".webcam_stream_container").hide()
    else 
      @quizIsShown = false
      $('#quiz_container').hide()
      $(".webcam_stream_container").show()
      @currentPowerup = new Powerup($('#powerup_container'))
      @currentPowerup.render()
      $('#powerup_container').show()
      @updatePowerupScreenFcn()
      if @readyForQuiz()  # TODO move this so that it fires randomly.
        console.log "Ready for quiz!"
        @createQuiz()


  handleIncomingQuiz: (snapshot, quizName) =>
    @emotionVideoStore.removeVideoItem(snapshot, @fbInteractor.fb_user_video_list)
    console.log "handling incoming quiz"
    quizEl = $(@elem.find("." + quizName))
    quizEl.css({"background-color": "#818181"})
    quiz = new Quiz(snapshot.emoticon, snapshot.choices, snapshot.v, snapshot.fromUser, @username, quizEl, snapshot.status, @username)
    quiz.render()
    quizEl.addClass("active").removeClass("inactive")
    @switchScreen(true)
    if snapshot.fromUser == @username
      quizEl.removeClass("enabled")
      quizEl.css({"background-color": "#818181"})
    else
      quizEl.addClass("enabled")
      quizEl.css({"background-color": "#9fbcd7"})
      quizChoiceSelector = "." + quizName + " .quiz-choice"
      console.log "selector here: " + quizChoiceSelector
      $(quizChoiceSelector).on "click", (evt) =>
        console.log 'removing'
        console.log quizChoiceSelector
        @respondToAnswerChoice(evt, quizChoiceSelector, quizName)

  getLongVideoArrays: =>
    longVideoArrs = {}
    for key, val of @emotionVideoStore.videos
      if _.size(val) >= MIN_REQUIRED_VIDEOS_FOR_QUIZ
        longVideoArrs[key] = val
    return longVideoArrs

  readyForQuiz: =>
    if @quizIsShown  # not ready for a quiz if there is already an active quiz
      return false
    # Find the two longest user arrays in the video store. Check if they are longer than the min required.
    # If both are, then return true.
    enoughUserVideos = @getLongVideoArrays()
    return _.size(enoughUserVideos) >= 2

  responsibleForMakingQuiz: (usernames) =>
    """Responsibility for making the quiz is determined by lexicographic ordering"""
    return _.every usernames, (otherUser) =>
      return @username >= otherUser

  createQuiz: =>
    enoughUserVideos = @getLongVideoArrays()
    usernames = _.keys(enoughUserVideos)
    if _.size(usernames) < 2
      console.error "Trying to create a quiz, but without enough user videos!"
      return
    if _.size(usernames) > 2
      console.error "There are more than 2 users, this may be bad!"  # TODO maybe handle this better
    if not @responsibleForMakingQuiz(usernames)
      console.log 'not responsible'
      return
    console.log 'responsible, making quiz'
    # This user is actually responsible for making the quiz
    # Choose a random video
    randomVideoOne = _.sample(enoughUserVideos[usernames[0]])
    @fbInteractor.fb_user_quiz_one.set(randomVideoOne)
    randomVideoTwo = _.sample(enoughUserVideos[usernames[1]])
    @fbInteractor.fb_user_quiz_two.set(randomVideoTwo)



class window.EmotionVideoStore
  """Stores a map from each user to a list of that user's emotion videos"""

  constructor: ->
    @videos = {}
    @fbResults = {}  # Store the result of pushing on the data so that we can remove it later

  addVideoSnapshot: (data) =>
    if data.fromUser not of @videos
      @videos[data.fromUser] = []
    @videos[data.fromUser].push(data)
    console.log "videos: "
    console.log @videos

  addUser: (username) =>
    if username of @videos
      return
    @videos[username] = []

  storePushedFb: (pushedFb, quickId) =>
    @fbResults[quickId] = pushedFb  # Store a mapping
    console.log quickId
    console.log @fbResults

  removeVideoSnapshot: (data) =>
    if data.fromUser not of @videos
      return
    @videos[data.fromUser] =
    @videos[data.fromUser] = _.reject @videos[data.fromUser], (item) =>
      return item.quickId == data.quickId
    console.log "((((((((( VIDEO REMOVED! videos: ))))))))) "
    console.log @videos
    console.log data

  removeVideoItem: (video, fb_video_list) =>
    if video.quickId not of @fbResults
      return
    pushedFb = @fbResults[video.quickId]
    if _.isUndefined(pushedFb)
      delete @fbResults[video.quickId]
      return
    pushedFb.remove()
    delete @fbResults[video.quickId]  # Remove from storing locally
    # Will be removed from local video store in the callback after deleting from Firebase.

class window.ChatRoom
  """Main class to control the chat room UI of messages and video"""
  constructor: (@fbInteractor, @videoRecorder) ->
    @lastPoster = null
    @backgroundColor = "#ffddc7"
    @emotionVideoStore = new EmotionVideoStore()
    @currentPowerup = new Powerup($('#powerup_container'))
    @currentPowerup.render()
    @quizCoordinator = new QuizCoordinator($("#quiz_container"), @emotionVideoStore, @fbInteractor, @currentPowerup, @updatePowerupScreen, false)
    @updatePowerupScreen()

    # Listen to Firebase events
    @fbInteractor.fb_instance_users.on "child_added", (snapshot) =>
      @displayMessage({m: " joined the room", c: snapshot.val().c, u: snapshot.val().name, j: "joined"})
      @emotionVideoStore.addUser(snapshot.val().name)
      @updatePowerupScreen()

    @fbInteractor.fb_instance_stream.on "child_added", (snapshot) =>
      msg = snapshot.val().m
      username = msg.substr(0, msg.indexOf(":"))
      spliced_message = msg.substr(msg.indexOf(":") + 1)
      console.log username
      #snapshot.val().u = username
      @displayMessage({m: spliced_message, c: snapshot.val().c, u: username})

    @fbInteractor.fb_user_video_list.on "child_added", (snapshot) =>
      @emotionVideoStore.addVideoSnapshot(snapshot.val())
      @updatePowerupScreen()
      if @quizCoordinator.readyForQuiz()  # TODO move this so that it fires randomly.
        console.log "Ready for quiz!"
        @quizCoordinator.createQuiz()

    @fbInteractor.fb_user_video_list.on "child_removed", (snapshot) =>
      @emotionVideoStore.removeVideoSnapshot(snapshot.val())

    @fbInteractor.fb_user_quiz_one.on "value", (snapshot) =>
      @respondToFbQuiz(snapshot, "quiz_one")


    @fbInteractor.fb_user_quiz_two.on "value", (snapshot) =>
      @respondToFbQuiz(snapshot, "quiz_two")

    @submissionEl = $("#submission input")

  updatePowerupScreen: =>
    context =
      usersAvailable: []
    for key, val of @emotionVideoStore.videos
      userContext = {"username": key, "numAvailable": _.size(val)}
      if _.size(val) >= MIN_REQUIRED_VIDEOS_FOR_QUIZ
        userContext["enoughVideos"] = true
      context.usersAvailable.push(userContext)
    html = window.Templates["powerup_available"](context)
    $(".powerup_available_videos").html(html)
    @updateProgressBar()

  updateProgressBar: =>
    # Hacky way to get the sum of the first and second biggest lengths of arrays for the top 2 users, where
    # each user can only contribute 2. Basically, of the 4 required videos, 2 from each user, how close are we.
    numberPerUserArr = []
    for key, val of @emotionVideoStore.videos
      numberPerUserArr.push(_.size(val))  # number available for this user.
    numberPerUserArr.sort()
    numberPerUserArr.reverse()
    sumOfBiggestTwo = 0
    if _.size(numberPerUserArr) >= 1
      sumOfBiggestTwo += Math.min(numberPerUserArr[0], 2)
    if _.size(numberPerUserArr) >= 2
      sumOfBiggestTwo += Math.min(numberPerUserArr[1], 2)

    newPercent = (sumOfBiggestTwo / (MIN_REQUIRED_VIDEOS_FOR_QUIZ * 2)) * 100
    if newPercent > 100
      newPercent = 100
    percentHundred = newPercent/100
    getProgressWrapWidth = $(".progress-wrap").width()
    progressTotal = percentHundred * getProgressWrapWidth
    animationLength = 1000 #lengthen to create animation
  
    # on page load, animate percentage bar to data percentage length
    $(".progress-bar").animate
      left: progressTotal
    , animationLength


  respondToFbQuiz: (snapshot, quizName) =>
    if not snapshot or not snapshot.val()
      return
    snapshotVal = snapshot.val()
    if snapshotVal.status == 'new quiz'
      @quizCoordinator.handleIncomingQuiz(snapshotVal, quizName)
    if snapshotVal.status == 'new guess'
      @quizCoordinator.handleGuessMade(snapshotVal, quizName)
    # Otherwise status is "quiz over"

  init: =>
    url = document.location.origin+"/#"+@fbInteractor.fb_chat_room_id
    @displayMessage({m: "Share this url with your friend to join this chat: <a href='" + url + "' target='_blank'>" + url+"</a>", c: "darkred"})
    # Block until user name entered
    @username = window.prompt("Welcome! What's your name?")  # Commented out for faster testing.
    if not @username
      @username = "anonymous"+Math.floor(Math.random()*1111)
    @quizCoordinator.setUserName(@username)
    @userColor = "#"+((1<<24)*Math.random()|0).toString(16) # Choose random color
    console.log("usercolor" + @userColor)
    @userColor = @userColor.substr(0,1) + '3' + @userColor.substr(2)
    @userColor = @userColor.substr(0,3) + '3' + @userColor.substr(4)
    console.log("usercolor" + @userColor)


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
          videoToPush =
            fromUser: @username
            c: @userColor
            v: @videoRecorder.curVideoBlob
            emoticon: emoticon
            choices: EmotionProcessor.makeQuizChoices(emoticon)
            status: "new quiz"
            quickId: Math.floor(Math.random()*1111)
          pushedFb = @fbInteractor.fb_user_video_list.push()
          pushedFb.set(videoToPush)
          [message, _] = EmotionProcessor.redactEmoticons(message) # Send the message with smiley redacted
          # We need to store the name so that we can retrieve it and remove the video
          # from the video list later on
          @emotionVideoStore.storePushedFb(pushedFb, videoToPush.quickId)
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
    changePoster = false
    if @lastPoster == null
      @lastPoster = data.u
    else
      if (@lastPoster != data.u)
        @lastPoster = data.u
        #swap background colors
        if @backgroundColor == "#f8ede6"
          @backgroundColor = "#ffddc7"
        else @backgroundColor = "#f8ede6"
        changePoster = true
    console.log data.j
    if changePoster
      if data.j == "joined"
        # poster just joined the room
        newHeader = $("<div class='msg' style='color:"+data.c+"'>"+data.u+data.m+"</div>")
        newMessage = null
      else
        newHeader = $("<div class='msg' style='color:"+data.c+"'>"+data.u+"</div>")
        newMessage = $("<div class='msgtext' style='color:"+data.c+"'>"+data.m+"</div>")
    else 
      newHeader = null
      newMessage = $("<div class='msgtext' style='color:"+data.c+"'>"+data.m+"</div>")
    
    if newHeader != null
      newHeader.css("font-weight", "bold")
      newHeader.css("font-style", "16px")
      newHeader.css("background-color", @backgroundColor)
      $("#conversation").append(newHeader)
    if newMessage != null
      newMessage.css("background-color", @backgroundColor)
      $("#conversation").append(newMessage)
    if data.v
      [source, video] = @createVideoElem(data.v)
      video.appendChild(source)
      document.getElementById("conversation").appendChild(video)
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



