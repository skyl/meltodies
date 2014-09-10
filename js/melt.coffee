'use strict'

window.MeltApp = angular.module 'MeltApp', ['ui.utils', 'ui.bootstrap', 'LocalStorageModule']


song_template = (scp) ->
  """
===
title: #{scp.title}
author: #{scp.author}
tube_id: #{scp.tube_id}
===
#{scp.song_data}
  """


# so changing YT doesn't affect back button,
# we just destroy and replace
youtube_iframe_template = (src) ->
  """
<iframe id="ytplayer" type="text/html" width="231" height="130"
    allowfullscreen="true"
    src="#{src}"
    frameborder="0"></iframe>
  """

# search
started = false
transition_search_input = (duration=100) ->
  s = d3.select(".start")
  # more duration once this gets worked out.
  # http://stackoverflow.com/q/25714744/177293
  s.transition().duration(duration)
      .style("margin-top", "1%")
  started = true


MeltController = ($scope, $http, $modal, $location, localStorageService) ->
  window.lss = localStorageService
  window.l = $location
  if $location.path()
    transition_search_input 0
  window.scope = $scope
  $scope.results = []
  $scope.ready_to_select = -1
  $scope.timeout = null
  $scope.selected = null

  $http(
    method: "GET"
    url: "songs.json"
  ).success((songs_json) ->
    $scope.songs_json = songs_json
    localStorageService.bind $scope, 'songs_json', songs_json
    $scope.onLoad()
  ).error(() ->
    # maybe we are offline or sth.
    # try to fallback to localStorage
    songs_json = localStorageService.get 'songs_json'
    if songs_json?
      $scope.songs_json = songs_json
      localStorageService.bind $scope, 'songs_json', songs_json
    $scope.onLoad()
  )

  $scope.onLoad = () ->
    # called when songs.json == data comes back
    document.getElementById("search").focus()
    # angular way to get path without / ?
    title = $location.path().split('/')[1]
    $scope.select_title title

  $scope.select_title = (title) ->
    if title isnt undefined and $scope.songs_json isnt undefined
      for d in $scope.songs_json
        if d.title.toLowerCase() == title.toLowerCase()
          $scope.select d
          # just select the first match
          # TODO - versions?
          return

  $scope.$on '$locationChangeSuccess', (scope, next, current) ->
    $scope.select_title $location.path().split('/')[1]

  $scope.update_results = ->
    if not started
      transition_search_input()

    document.getElementById('search-list').scrollTop = 0
    $scope.ready_to_select = -1

    words = $scope.query.split(' ')
    #console.log "start", words
    authstr = "author:"
    filtered_words = (w for w in words when (not (w.substring(0, authstr.length) is authstr)))
    authorstrs = (w for w in words when (w.substring(0, authstr.length) is authstr))
    a_search = (a.split(":")[1] for a in authorstrs)
    #console.log "filtered", filtered_words
    #console.log "authors", a_search
    window.filterf = (datum) ->
      for word in filtered_words
        if datum.title.toLowerCase().indexOf(word.toLowerCase()) < 0
          return false
      if datum.author?
        for author_word in a_search
          if datum.author.toLowerCase().indexOf(author_word.toLowerCase()) < 0
            return false
      true
    res = _.filter($scope.songs_json, filterf)
    $scope.results = res
    return

  $scope.query_key = ($event) ->
    $event.preventDefault()
    can_up = $scope.ready_to_select > 0
    can_down = $scope.ready_to_select < $scope.results.length - 1
    not_over = $scope.ready_to_select < $scope.results.length
    has_items = $scope.results.length > 0
    can_select = $scope.ready_to_select > -1 and not_over and has_items

    if $event.keyCode is 40
      key = "Down"
    else if $event.keyCode is 38
      key = "Up"
    else if $event.keyCode is 13
      key = "Enter"
    else
      $scope.ready_to_select = -1
      $scope.query = ""
      $scope.results = []
      document.getElementById('search-list').scrollTop = 0
      return

    if key is "Down"
      if can_down
        $scope.ready_to_select += 1
        # TODO: refine - no magic numbers
        if $scope.ready_to_select > 3
          document.getElementById('search-list').scrollTop += 25
      else
        # go to top
        $scope.ready_to_select = 0
        document.getElementById('search-list').scrollTop = 0
    else if key is "Up"
      if can_up
        $scope.ready_to_select -= 1
        # TODO: refine - no magic numbers
        if $scope.ready_to_select < $scope.results.length - 3
          document.getElementById('search-list').scrollTop -= 25
      else
        # go to bottom
        $scope.ready_to_select = $scope.results.length - 1
        document.getElementById('search-list').scrollTop = 9999999
    else if (key is "Enter" and can_select)
      selected = $scope.results[$scope.ready_to_select]
      $scope.select selected
      $scope.ready_to_select = -1
    else
      $scope.ready_to_select = -1

  $scope.mouseover = (idx) ->
    $scope.ready_to_select = idx
  $scope.mouseleave = (idx) ->
    $scope.ready_to_select = -1
  $scope.select = (datum) ->
    $scope.query = ""
    $scope.results = []
    $scope.selected = datum

    hydrate = (song_text) ->
      # we assume that the song is in the correct format
      $scope.song_meta = song_text.split('===')[1].trim()
      $scope.song_data = song_text.split('===')[2].trim()
      metal = jsyaml.load($scope.song_meta)
      $scope.tube_id = metal.tube_id
      if $scope.tube_id
        # we have to replace the iframe so it doesn't mess up
        # our back button hotness.
        ytel = document.getElementById("tube-container")
        ytel.innerHTML = youtube_iframe_template(
          "http://www.youtube.com/embed/#{$scope.tube_id}"
        )
      if metal.title.toLowerCase() isnt $location.path().toLowerCase()
        $location.path metal.title
      _setColumnWidth Math.round(
        _.max($scope.song_data.split("\n")).length * (window.devicePixelRatio || 1)
      )
      document.getElementById('song-meta').innerHTML = $scope.song_meta
      document.getElementById('pre-song').innerHTML = $scope.song_data
    _setColumnWidth = (column_width) ->
      els = document.querySelectorAll(".song")
      w = column_width + "em"
      for el in els
        el.style["-webkit-column-width"] = w
        el.style["-moz-column-width"] = w
        el.style["column-width"] = w

    $http(
      method: "GET",
      url: datum.file
    ).success((song_text) ->
      hydrate song_text
      localStorageService.set datum.file, song_text
    ).error(()->
      song_text = localStorageService.get datum.file
      if song_text?
        hydrate song_text
    )


  # Github
  OAuth.initialize 'suDFbLhBbbZAzBRH-CFx5WBoQLU'
  $scope.login = () ->
    OAuth.popup 'github', $scope.loginCallback
  $scope.loginCallback = (err, github_data) ->
    console.log err, github_data
    $scope.github_access_token = github_data.access_token
    window.gh = $scope.github = new Github {
      token: $scope.github_access_token,
      auth: "oauth"
    }
    $scope.$apply()

    $scope.user = gh.getUser()
    $scope.user.getInfo().then (d) ->
      $scope.userInfo = d
    $scope.user.follow "pdh"
    $scope.user.follow "skyl"
    $scope.user.putStar "pdh", "meltodies"
    $scope.upstream_repo = gh.getRepo "pdh", "meltodies"
    $scope.upstream_repo.fork()

  # add song
  $scope.start_add = () ->
    query = $scope.query
    modalInstance = $modal.open
      templateUrl: 'addSongModal.html'
      controller: AddSongModalCtrl
      size: 'lg',
      resolve:
        title: () ->
          $scope.query

    complete = (data) ->
      # TODO - people can make illegal titles?
      branchname = data.title.toLowerCase().replace /\ /g, '_'
      filename = "#{branchname}.melt"
      file = song_template(data)
      user_repo = $scope.github.getRepo $scope.userInfo.login, "meltodies"
      master = user_repo.getBranch('master')
      path = "melts/#{filename}"

      changes = {}
      changes[path] = file
      # just one file? ok.
      _onBranch = (a, b, c) ->
        branch = user_repo.getBranch(branchname)
        branch.writeMany(changes, "add #{data.title}").then(
          (() ->
            $scope.upstream_repo.createPullRequest
              "title": "add #{data.title}"
              "head": "#{$scope.userInfo.login}:#{branchname}"
              "base": "master"
          ),
          ((a, b, c) ->
            console.log "FAILED TO CREATE createPullRequest!", a, b, c
          )
        )
        $scope.query = ""
        $scope.$apply()

      # we try to create the branch
      # we assume that the failure is b/c we already have the branch created
      # so, pass or fail, we do the same thing -
      # write the file and make the pull request.
      master.createBranch(branchname).then _onBranch, _onBranch

    dimissed = () ->
      console.log "DISMIESSED!"

    modalInstance.result.then complete, dimissed


AddSongModalCtrl = ($scope, $modalInstance, title) ->
  # wtf, bro
  # http://stackoverflow.com/a/22172612/177293
  # http://stackoverflow.com/q/18716113/177293
  window.modal_scope = $scope
  $scope.data =
    title: title
    author: null
    tube_id: null
    song_data: null

  # TODO - validation

  $scope.ok = () ->
    $modalInstance.close($scope.data)

  $scope.cancel = () ->
    $modalInstance.dismiss('cancel')


MeltController.$inject = ['$scope', '$http', '$modal', '$location', 'localStorageService']
angular.module('MeltApp').controller 'MeltController', MeltController
