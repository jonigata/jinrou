exports.start=(rolename)->
	# 配役表 例)普通配役-普通1
	try
		rolename=decodeURIComponent rolename
	func=Shared.game.getrulefunc rolename.replace "-","."
	rolename.replace "-","."
	unless func?
		p=document.createElement "p"
		p.textContent="その配役表は利用できません。"
		document.body.appendChild p
		return
	if result=rolename.match /^(.+)\-([^\-]+)$/
		$("#rolename").text result[2]

	jobs=[null]	# 出現する役職の一覧
	
	the=$("#rolehead").get 0
	thr=the.insertRow 0
	th=document.createElement "th"
	th.textContent="人数"
	thr.appendChild th

	appendjob=(type)->
		th=document.createElement "th"
		a=document.createElement "a"
		a.href="/manual/job/#{type}"
		a.textContent=getjobname type
		th.appendChild a
		jobs.push type
		thr.appendChild th
	appendjob "Human"
	
	
	tb=$("#rolebody").get 0
	
	count=0	# 何個行をつくったか
	max=30	# 最大
	index=6	# 現在の人数
	while count<max
		obj=func index
		sum=0

		for key,value of obj
			sum+=value
			unless key in jobs	#新出の役職
				appendjob key
			
			
		obj.Human=index-sum	# 村人数算出
		if obj.Human<0	# 足りない
			index++
			continue
		
		tr=tb.insertRow -1
		td=tr.insertCell 0
		td.textContent=index	# 人数
		while tr.cells.length < jobs.length
			tr.insertCell -1
		for key,value of obj
			if value>0
				td=tr.cells[jobs.indexOf key]
				td?.textContent=value
		index++
		count++
		

			

exports.end=->

getjobname=(type)->
	for teamname,arr of Shared.game.teams
		if type in arr
			return Shared.game.jobinfo[teamname][type].name
	return null

