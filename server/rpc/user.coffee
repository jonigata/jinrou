# Server-side Code
Shared=
	game:require '../../client/code/shared/game.coffee'
	prize:require '../../client/code/shared/prize.coffee'
Server=
	user:module.exports
	prize:require '../prize.coffee'
	oauth:require '../oauth.coffee'
crypto=require('crypto')

# 内部関数的なログイン
login= (query,req,cb,ss)->
	auth=require('./../auth.coffee')
	#req.session.authenticate './session_storage/internal.coffee', query, (response)=>
	auth.authenticate query,(response)=>
		if response.success
			req.session.setUserId response.userid
			response.ip=req.clientIp
			req.session.user=response
			#req.session.room=null	# 今入っている部屋
			req.session.channel.reset()
			cb false
			# IPアドレスを記録してあげる
			M.users.update {"userid":response.userid},{$set:{ip:response.ip}}
		else
			cb true

exports.actions =(req,res,ss)->
	req.use 'session'

# ログイン
# cb: 失敗なら真
	login: (query)->
		login query,req,res,ss
	
# ログアウト
	logout: ->
		#req.session.user.logout(cb)
		req.session.channel.reset()
		res()
			
# 新規登録
# cb: エラーメッセージ（成功なら偽）
	newentry: (query)->
		unless /^\w+$/.test(query.userid)
			res "ユーザーIDが不正です"
			return
		unless /^\w+$/.test(query.password)
			res "パスワードが不正です"
			return
		M.users.find({"userid":query.userid}).count (err,count)->
			if count>0
				res "そのユーザーIDは既に使用されています"
				return
			userobj = makeuserdata(query)
			M.users.insert userobj,{safe:true},(err,records)->
				if err?
					res "DB err:#{err}"
					return
				login query,req,res,ss
				
# ユーザーデータが欲しい
	userData: (userid,password)->
		M.users.findOne {"userid":userid},(err,record)->
			if err?
				res null
				return
			if !record?
				res null
				return
			delete record.password
			delete record.prize
			#unless password && record.password==SS.server.user.crpassword(password)
			#	delete record.email
			res record
	myProfile: ->
		unless req.session.userId
			res null
			return
		u=JSON.parse JSON.stringify req.session.user
		if u
			u.wp = unless u.win? && u.lose?
				"???"
			else if u.win.length+u.lose.length==0
				"???"
			else
				"#{(u.win.length/(u.win.length+u.lose.length)*100).toPrecision(2)}%"
			# 称号の処理をしてあげる
			u.prize ?= []
			u.prizenames=u.prize.map (x)->{id:x,name:Server.prize.prizeName(x) ? null}
			delete u.prize
			res u
		else
			res null
		
				
# プロフィール変更 返り値=変更後 {"error":"message"}
	changeProfile: (query)->
		M.users.findOne {"userid":req.session.userId,"password":Server.user.crpassword(query.password)},(err,record)=>
			if err?
				res {error:"DB err:#{err}"}
				return
			if !record?
				res {error:"ユーザー認証に失敗しました"}
				return
			if query.name?
				if query.name==""
					res {error:"ニックネームを入力して下さい"}
					return
					
				record.name=query.name
			if query.email?
				record.email=query.email
			if query.comment? && query.comment.length<=200
				record.comment=query.comment
			if query.icon? && query.icon.length<=300
				record.icon=query.icon
			M.users.update {"userid":req.session.userId}, record, {safe:true},(err,count)=>
				if err?
					res {error:"プロフィール変更に失敗しました"}
					return
				delete record.password
				req.session.user=record
				req.session.save ->
				res record
	changePassword:(query)->
		M.users.findOne {"userid":req.session.userId,"password":Server.user.crpassword(query.password)},(err,record)=>
			if err?
				res {error:"DB err:#{err}"}
				return
			if !record?
				res {error:"ユーザー認証に失敗しました"}
				return
			if query.newpass!=query.newpass2
				res {error:"パスワードが一致しません"}
				return
			M.users.update {"userid":req.session.userId}, {$set:{password:Server.user.crpassword(query.newpass)}},{safe:true},(err,count)=>
				if err?
					res {error:"プロフィール変更に失敗しました"}
					return
				res null
	usePrize: (query)->
		# 表示する称号を変える query.prize
		M.users.findOne {"userid":req.session.userId,"password":Server.user.crpassword(query.password)},(err,record)=>
			if err?
				res {error:"DB err:#{err}"}
				return
			if !record?
				res {error:"ユーザー認証に失敗しました"}
				return
			if typeof query.prize?.every=="function"
				# 称号構成を得る
				comp=Shared.prize.getPrizesComposition record.prize.length
				if query.prize.every((x,i)->x.type==comp[i])
					# 合致する
					if query.prize.every((x)->
						if x.type=="prize"
							!x.value || x.value in record.prize	# 持っている称号のみ
						else
							!x.value || x.value in Shared.prize.conjunctions
					)
						# 所持もOK
						M.users.update {"userid":req.session.userId}, {$set:{nowprize:query.prize}},{safe:true},(err)=>
								req.session.user.nowprize=query.prize
							req.session.save ->
							
							res null
					else
						res {error:"肩書きが不正です"}
				else
					res {error:"肩書きが不正です"}
			else
				res {error:"肩書きが不正です"}
		
	# 成績をくわしく見る
	analyzeScore:->
		unless req.session.userId
			res {error:"ログインして下さい"}
			return
		myid=req.session.userId
		# DBから自分のやつを引っ張ってくる
		results=[]
		cursor=M.games.find {finished:true,players:{$elemMatch:{realid:myid}}}
		cursor.each (err,game)->
			unless game?
				# 終了
				res {results:results}
				return
			player=game.players.filter((x)->x.realid==myid)[0] # me
			return unless player?
			plinfo=(pl)->
				unless pl.type=="Complex"
					{type:pl.type, winner:pl.winner}
				else
					plinfo pl.Complex_main
			pobj=plinfo player
			pobj.id=game.id
			results.push pobj
			
	
	######
			


#パスワードハッシュ化
#	crpassword: (raw)-> raw && hashlib.sha256(raw+hashlib.md5(raw))
exports.crpassword= (raw)->
		return "" unless raw
		sha256=crypto.createHash "sha256"
		md5=crypto.createHash "md5"
		md5.update raw	# md5でハッシュ化
		sha256.update raw+md5.digest 'hex'	# sha256でさらにハッシュ化
		sha256.digest 'hex'	# 結果を返す
#ユーザーデータ作る
makeuserdata=(query)->
	{
		userid: query.userid
		password: Server.user.crpassword(query.password)
		name: query.userid
		icon:""	# iconのURL
		comment: ""
		win:[]	# 勝ち試合
		lose:[]	# 負け試合
		gone:[]	# 行方不明試合
		ip:""	# IPアドレス
		prize:[]# 現在持っている称号
		ownprize:[]	# 何かで与えられた称号（prizeに含まれる）
		nowprize:null	# 現在設定している肩書き
				# [{type:"prize",value:(prizeid)},{type:"conjunction",value:"が"},...]
	}
