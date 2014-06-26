class Wallet

    accounts: {}

    balances: {}

    transactions: {}

    trust_levels: {}

    timeout=60000

    refresh_balances: ->
        @wallet_api.account_balance("").then (result) =>
            angular.forEach result, (name_bal_pair) =>
                name = name_bal_pair[0]
                balances = name_bal_pair[1]
                angular.forEach balances, (symbol_amt_pair) =>
                    symbol = symbol_amt_pair[0]
                    amount = symbol_amt_pair[1]
                    @blockchain.get_asset_record(symbol).then (asset_record) =>
                        @balances[name][symbol] = @utils.newAsset(amount, symbol, asset_record.precision)

    # turn raw rpc return value into nice object
    populate_account: (val) ->
        if not @balances[val.name]
            @balances[val.name] =
                "XTS": @utils.newAsset(0, "XTS", 1000000) #TODO move to utils/config
        @trust_levels[val.name] = val.trust_level
        acct = val
        acct["active_key"] = val.active_key_history[val.active_key_history.length - 1][1]
        @accounts[acct.name] = acct
        return acct

    refresh_account: (name) ->
        @wallet_api.get_account(name).then (result) => # TODO no such acct?
            @populate_account(result)
            @refresh_transactions_on_update()

    refresh_accounts: ->
        @wallet_api.list_accounts().then (result) =>
            angular.forEach result, (val) =>
                @populate_account(val)
            @refresh_balances()

    get_setting: (name) ->
        @wallet_api.get_setting(name).then (result) =>
            result

    set_setting: (name, value) ->
        @wallet_api.set_setting(name, value).then (result) =>
            result

    create_account: (name, privateData) ->
        @wallet_api.account_create(name, privateData).then (result) =>
            console.log(result)
            @refresh_accounts()

    account_update_private_data: (name, privateData) ->
        @wallet_api.account_update_private_data(name, privateData).then (result) =>
            console.log(result)
            @refresh_accounts()

    get_account: (name) ->
        @refresh_balances()
        if @accounts[name]
            deferred = @q.defer()
            deferred.resolve(@accounts[name])
            return deferred.promise
        else
            @wallet_api.get_account(name).then (result) =>
                acct = @populate_account(result)
                return acct
            ,
            (error) =>
                @blockchain_api.get_account_record(name).then (result) =>
                    acct = @populate_account(result)
                    return acct

    set_trust: (name, trust_level) ->
        @trust_levels[name] = trust_level
        @wallet_api.set_delegate_trust(name, trust_level).then () =>
            @refresh_account(name)
        return
    
    refresh_transactions_on_update: () ->
        @refresh_transactions()
        angular.forEach @accounts, (account, name) =>
            if account.is_my_account
                @refresh_transactions(name)

    refresh_transactions: (account_name) ->
        account_name_key = account_name || "*"
        @wallet_api.account_transaction_history(account_name).then (result) =>
            @transactions[account_name_key] = []
            angular.forEach result, (val, key) =>
                blktrx=val.block_num + "." + val.trx_num
                @transactions[account_name_key].push
                    block_num: ((if (blktrx is "-1.-1") then "Pending" else blktrx))
                    #trx_num: Number(key) + 1
                    time: new Date(val.received_time*1000)
                    amount: val.amount
                    from: val.from_account
                    to: val.to_account
                    memo: val.memo_message
                    id: val.trx_id.substring 0, 8
                    fee: @utils.newAsset(val.fees, "XTS", 1000000) #TODO
                    vote: "N/A"
            if account_name_key == "*"
                @set_setting("wallet_trx_count", @transactions[account_name_key].length)
            @transactions[account_name_key]

    refresh_transactions_on_new_block: () ->
        @get_setting("wallet_trx_count").then (result)=>
            current_count = if result then result.value || 0
            @refresh_transactions().then =>
                if @transactions["*"].length > current_count
                    @growl.notice "", "You just received a new transaction!"
                    angular.forEach @accounts, (account, name) =>
                        if account.is_my_account
                            @refresh_transactions(name)

    # TODO: search for all deposit_op_type with asset_id 0 and sum them to get amount
    # TODO: sort transactions, show the most recent ones on top
    get_transactions: (account_name) ->
        account_name_key = account_name || "*"
        if @transactions[account_name_key]
            deferred = @q.defer()
            deferred.resolve(@transactions[account_name_key])
            return deferred.promise
        else
            @wallet_api.account_transaction_history(account_name).then (result) =>
                @transactions[account_name_key] = []
                angular.forEach result, (val, key) =>
                    blktrx=val.block_num + "." + val.trx_num
                    @transactions[account_name_key].push
                        block_num: ((if (blktrx is "-1.-1") then "Pending" else blktrx))
                        #trx_num: Number(key) + 1
                        time: new Date(val.received_time*1000)
                        amount: val.amount
                        from: val.from_account
                        to: val.to_account
                        memo: val.memo_message
                        id: val.trx_id.substring 0, 8
                        fee: @utils.newAsset(val.fees, "XTS", 1000000) #TODO
                        vote: "N/A"
                @transactions[account_name_key]

    create: (wallet_name, spending_password) ->
        @rpc.request('wallet_create', [wallet_name, spending_password])

    get_balance: ->
        @rpc.request('wallet_get_balance').then (response) ->
            asset = response.result[0]
            {amount: asset[0], asset_type: asset[1]}

    get_wallet_name: ->
        @rpc.request('wallet_get_name').then (response) =>
          console.log "---- current wallet name: ", response.result
          @wallet_name = response.result
    
    wallet_get_info: ->
        @rpc.request('wallet_get_info').then (response) =>
            response.result

    wallet_add_contact_account: (name, address) ->
        @rpc.request('wallet_add_contact_account', [name, address]).then (response) =>
          response.result

    wallet_account_register: (account_name, pay_from_account, public_data, as_delegate) ->
        as_delegate = if as_delegate == undefined then 255 else as_delegate
        @rpc.request('wallet_account_register', [account_name, pay_from_account, public_data, as_delegate]).then (response) =>
          response.result

    wallet_rename_account: (current_name, new_name) ->
        @rpc.request('wallet_rename_account', [current_name, new_name]).then (response) =>
          response.result

    wallet_unlock: (password)->
        @rpc.request('wallet_unlock', [timeout, password]).then (response) =>
          response.result

    check_if_locked: ->
        @rpc.request('wallet_get_info').then (response) =>
            if response.result.locked
                @location.path("/unlockwallet")

    open: ->
        @rpc.request('wallet_open', ['default']).then (response) =>
          response.result

    wallet_account_balance: ->
        @rpc.request('wallet_account_balance').then (response) ->
          response.result

    get_block: (block_num)->
        @rpc.request('blockchain_get_block_by_number', [block_num]).then (response) ->
          response.result

    wallet_remove_contact_account: (name)->
        @rpc.request('wallet_remove_contact_account', [name]).then (response) ->
          response.result

    wallet_lock: ->
        @rpc.request('wallet_lock').then (response) ->
          response.result

    wallet_list_accounts: ->
        @rpc.request('wallet_list_accounts').then (response) ->
          response.result
        
    constructor: (@q, @log, @location, @growl, @rpc, @blockchain, @utils, @wallet_api, @blockchain_api, @interval) ->
        @log.info "---- Wallet Constructor ----"
        @wallet_name = ""

angular.module("app").service("Wallet", ["$q", "$log", "$location", "Growl", "RpcService", "Blockchain", "Utils", "WalletAPI", "BlockchainAPI", "$interval", Wallet])
