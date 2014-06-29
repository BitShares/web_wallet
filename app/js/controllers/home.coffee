
angular.module("app").controller "HomeController", ($scope, $modal, Shared, $log, RpcService, Wallet, Growl) ->
	###
  $scope.transactions = []
  $scope.balance_amount = 0.0
  $scope.balance_asset_type = ''

  watch_for = ->
    Wallet.info

  on_update = (info) ->
    $scope.balance_amount = info.balance if info.wallet_open

  $scope.$watch(watch_for, on_update, true)


  Wallet.wallet_account_balance().then (balance)->
    console.log(balance)


  Wallet.get_balance().then (balance)->
    $scope.balance_amount = balance.amount
    $scope.balance_asset_type = balance.asset_type
    Wallet.get_transactions().then (trs) ->
      $scope.transactions = trs

  # Merge: this duplicates the code in transactions.coffee
  $scope.viewAccount = (name)->
    Shared.accountName  = name
    Shared.accountAddress = "TODO:  Look the address up somewhere"
    Shared.trxFor = name

  $scope.viewContact = (name)->
    Shared.contactName  = name
    Shared.contactAddress = "TODO:  Look the address up somewhere"
    Shared.trxFor = name
###


angular.module("app").controller "FooterController", ($scope, Wallet, Utils) ->
  $scope.connections = 0
  $scope.blockchain_blocks_behind = 0
  $scope.blockchain_status = "off"
  $scope.blockchain_last_block_num = 0
  $scope.alert_level = "normal-state"

  watch_for = ->
    Wallet.info

  on_update = (info) ->
    connections = info.network_connections
    $scope.connections = connections
    if connections == 0
      $scope.connections_str = "Not connected to the network"
    else if connections == 1
      $scope.connections_str = "1 network connection"
    else
      $scope.connections_str = "#{connections} network connections"

    if connections < 4
      $scope.connections_img = "/img/signal_#{connections}.png"
    else
      $scope.connections_img = "/img/signal_4.png"

    $scope.wallet_unlocked = info.wallet_unlocked

    if info.last_block_time
      seconds_diff = (Date.now() - Utils.toDate(info.last_block_time).getTime()) / 1000
      hours_diff = Math.floor seconds_diff / 3600
      minutes_diff = (Math.floor seconds_diff / 60) % 60
      hours_diff_str = if hours_diff == 1 then "#{hours_diff} hour" else "#{hours_diff} hours"
      minutes_diff_str = if minutes_diff == 1 then "#{minutes_diff} minute" else "#{minutes_diff} minutes"
      $scope.blockchain_blocks_behind = Math.floor seconds_diff / 30
      $scope.blockchain_time_behind = "#{hours_diff_str} #{minutes_diff_str}"
      $scope.blockchain_status = if $scope.blockchain_blocks_behind < 2 then "synced" else "syncing"
      $scope.blockchain_last_block_num = info.last_block_num
      if seconds_diff > 32
        $scope.blockchain_last_sync_info = "Last block is synced " + info.last_block_time_rel + " "
      else
        $scope.blockchain_last_sync_info = "Blocks are synced "
    else
      $scope.blockchain_status = "off"
      $scope.blockchain_last_sync_info = " Blocks are syncing ..."

    
    if info.alert_level == "green"
      $scope.alert_level = "normal-state"
    else if info.alert_level == "yellow"
      $scope.alert_level = "warning-state"
    else
      $scope.alert_level = "severe-state"

  $scope.$watch(watch_for, on_update, true)
