# OAuth twitter client

twitter = require('twitter')
twit = new twitter({
	consumer_key:Config.twitter.oauth.consumerKey,
	consumer_secret:Config.twitter.oauth.consumerSecret,
	access_token_key:Config.twitter.oauth.accessToken,
	access_token_secret:Config.twitter.oauth.accessTokenSecret,
})

tweet=(message,pass)->
	return unless pass==Config.admin.password
	
	twit.post '/statuses/update.json',{status:message},(data)->
		console.log data
		rt_names=[]


# #人狼募集 RT bot
###
rt_names = []	# RTした人（直近5人）
twit.stream 'statuses/filter',{track:'#人狼募集'}, (stream)->
	stream.on 'data',(data)->
		if data?
			# ツイートが来たのでRTする
			unless rt_names.length>=5 && rt_names.every((x)->x==data.user.screen_name)
				if data.user.screen_name!="jinroutter"	#hard coding
					setTimeout (->
						twit.post "/statuses/retweet/#{data.id_str}.json",{trim_user:true},(data2)->
					),1000
					rt_names=rt_names.concat(data.user.screen_name).slice -5
###

exports.tweet=tweet
exports.template=(roomid,message,pass)->
		tweet "#{message} \u2013 #{Config.application.url}room/#{roomid}",pass
		

