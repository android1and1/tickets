# firssts of first check if 'redis-server' is running.
{spawn} = require 'child_process'
# this for redis promisify(client.get),the way inpirit from npm-redis.
{promisify} = require 'util'
pgrep = spawn '/usr/bin/pgrep',['redis-server']
pgrep.on 'close',(code)->
  if code isnt 0
    console.log 'should run redis-server first.'
    process.exit 1

path = require 'path'
fs = require 'fs'
http = require 'http'
qr_image = require 'qr-image'
formidable = require 'formidable'
crypto = require 'crypto'

# super-user's credential
fs.stat './configs/credentials/super-user.js',(err,stats)->
  if err 
    console.log 'Credential File Not Exists,Fix It.'
    process.exit 1

credential = require './configs/credentials/super-user.js'
hostname = require './configs/hostname.js'
superpass = credential.password
# ruler for daka app am:7:30 pm:18:00
ruler = require './configs/ruler-of-daka.js'

{Nohm} = require 'nohm'
Account = require './modules/md-account'
Daka = require './modules/md-daka'
dakaModel = undefined
accountModel = undefined
TICKET_PREFIX = 'ticket'
TICKET_MEDIA_ROOT = path.join __dirname,'public','tickets'
DAKA_WILDCARD = 'DaKa*daily*'
ACCOUNT_WILDCARD='DaKa*account*'

redis = (require 'redis').createClient()

setAsync = promisify redis.set
  .bind redis
getAsync = promisify redis.get
  .bind redis
expireAsync = promisify redis.expire
  .bind redis
existsAsync = promisify redis.exists
  .bind redis

delAsync = (key)->
  new Promise (resolve,reject)->
    redis.del key,(err,intReply)->
      if err
        reject err
      else
        resolve intReply 

hgetAsync = (key,index)->
  new Promise (resolve,reject)->
    redis.hget key,index,(err,value)->
      if err
        reject err
      else
        resolve value 

hgetallAsync = (key)->
  new Promise (resolve,reject)->
    redis.hgetall key,(err,record)->
      if err
        reject err
      else
        resolve record
lrangeAsync = (key,start,end)->
  new Promise (resolve,reject)->
    redis.lrange key,start,end,(err,items)->
      if err
        reject err
      else
        resolve items 

redis.on 'error',(err)->
  console.log 'Heard that:',err

redis.on 'connect',->
  Nohm.setClient @
  Nohm.setPrefix 'DaKa' # the main api name.
  # register the 2 models.
  dakaModel = Nohm.register Daka
  accountModel = Nohm.register Account

express = require 'express'
app = express()
app.set 'view engine','pug'
STATIC_ROOT = path.join __dirname,'public'
app.use express.static STATIC_ROOT 

# enable "req.body",like the old middware - "bodyParser"
app.use express.urlencoded({extended:false})

# session
Session = require 'express-session'
Store = (require 'connect-redis') Session

# authenticate now
redis_auth_pass = require './configs/redis/auth_pass.js'
redis.auth redis_auth_pass,(err,reply)->
  if err
    console.error 'redis db authenticate failure.'
    return process.exit -1 

# start add all  middle-ware
app.use Session {
    cookie:
      maxAge: 86400 * 1000  # one day. 
      httpOnly:true
      path:'/'  # 似乎太过宽泛，之后有机会会琢磨这个
    secret: 'youkNoW.'
    store: new Store {client:redis}
    resave:false
    saveUninitialized:true
  } 

app.use (req,res,next)->
  res.locals.referrer = req.session.referrer
  delete req.session.referrer  # then,delete() really harmless
  next()

app.get '/',(req,res)->
  role = req.session?.auth?.role
  alias = req.session?.auth?.alias
  if role is 'unknown' and alias is 'noname'
    [role,alias] = ['visitor','hi']
  res.render 'index'
    ,
    title:'welcome-daka'
    role:role
    alias:alias

app.get '/create-check-words',(req,res)->
  # 如果用户选择了填表单方式来打卡。
  digits = [48..57] # 0..9
  alpha = [97...97+26] # A..Z
  chars = digits.concat alpha
    .concat digits
    .concat alpha
  # total 72 chars,so index max is 72-1=71
  {round,random} = Math
  words = for _ in [1..5]  # make length=5 words
    index = round random()*71
    String.fromCharCode chars[index]
  words = words.join ''
  # 存储check words到redis数据库，并设置超时条件。
  await setAsync 'important',words
  await expireAsync 'important',60
  res.json words
  
app.get '/create-qrcode',(req,res)->
  # the query string from user-daka js code(img.src=url+'....')
  # query string include socketid,timestamp,and alias
  text = [req.query.socketid,req.query.timestamp].join('-')
  await setAsync 'important',text
  await expireAsync 'important',60
  # templary solid ,original mode is j602 
  fulltext = hostname + '/user/daka-response?mode=' + req.query.mode + '&&alias=' + req.query.alias + '&&check=' + text 
  res.type 'png'
  qr_image.image(fulltext).pipe res 
# maniuate new func or new mind.

app.get '/user/daka',(req,res)->
  if req.session?.auth?.role isnt 'user'
    req.session.referrer = '/user/daka'
    res.redirect 303,'/user/login'
  else
    # check which scene the user now in?
    user = req.session.auth.alias
    # ruler object 
    today = new Date 
    today.setHours ruler.am.hours
    today.setMinutes ruler.am.minutes
    today.setSeconds 0
    ids = await dakaModel.find {alias:user,utc_ms:{min:Date.parse today}}
    # mode变量值为0提示“入场”待打卡状态，1则为“出场”待打卡状态。
    res.render 'user-daka',{mode:ids.length,alias:user,title:'User DaKa Console'}

app.get '/user/login',(req,res)->
  res.render 'user-login',{title:'Fill User Login Form'}

app.post '/user/login',(req,res)->
  # reference line#163
  {itisreferrer,alias,password} = req.body
  itisreferrer = itisreferrer or '/user/login-success'
  # filter these 2 strings for anti-injecting
  isInvalidation = (! filter alias or ! filter password)
  if isInvalidation 
    return res.render 'user-login-failure',{reason: '含有非法字符（只允许ASCII字符和数字)!',title:'User-Login-Failure'}
  # auth initialize
  initSession req
  # first check if exists this alias name?
  # mobj is 'match stats object'
  mobj = await matchDB accountModel,alias,'user',password
  if mobj.match_result 
    # till here,login data is matches.
    updateAuthSession req,'user',alias
    res.redirect 303,itisreferrer
  else
    updateAuthSession req,'unknown','noname'
    return res.render 'user-login-failure',{reason: '用户登录失败，原因：帐户不存在／帐户被临时禁用／账户口令不匹配。',title:'User-Login-Failure'}

app.put '/user/logout',(req,res)->
  role = req.session?.auth?.role
  if role is 'user'
    req.session.auth.role = 'unknown'
    req.session.auth.alias = 'noname'
    res.json {code:0,reason:'',status:'logout success'}
  else
    res.json {code:-1,reason:'No This Account Or Role Isnt User.',status:'logout failure'}
    
app.get '/user/login-success',(req,res)->
  res.render 'user-login-success',{title:'User Role Validation:successfully'}

# user choiced alternatively way to daka
app.post '/user/daka-response',(req,res)->
  check = req.body.check
  # get from redis db
  words = await getAsync 'important'
  session_alias = req.session?.auth?.alias
  if words is check  
    # save this daka-item
    try
      obj = new Date
      desc = obj.toString()
      ms = Date.parse obj 
      ins = await Nohm.factory 'daily'
      ins.property
        alias: session_alias 
        utc_ms: ms
        whatistime: desc 
        browser: req.headers["user-agent"] 
        category:req.body.mode # 'entry' or 'exit' mode
      await ins.save()
      # notice admin with user's success.
      # the .js file include socket,if code=0,socket.emit 'code','0'
      return res.render 'user-daka-response-success',{code:'0',title:'login Result',status:'打卡成功',user:session_alias}
    catch error
      # notice admin with user's failure.
      # js file include socket,if code=-1,socket.emit 'code','-1'
      # show db errors
      console.dir ins.errors
      return res.render 'user-daka-response-failure',{title:'daka failure','reason':ins.errors,code:'-1',user:session_alias,status:'数据库错误，打卡失败。'}
  else
    return res.render 'user-daka-response-failure',{title:'daka failure',status:'打卡失败',code:'-1',reason:'超时或验证无效',user:session_alias}

# user daka via QR code (scan software)
app.get '/user/daka-response',(req,res)->
  session_alias = req.session?.auth?.alias
  if session_alias is undefined
    req.session.referrer = '/user/daka-response'
    return res.redirect 303,'/user/login'
  if req.query.alias isnt session_alias 
    return res.json {status:'alias inconsistent',warning:'you should requery daka and visit this page via only one browser',session:session_alias,querystring:req.query.alias}
  # user-daka upload 'text' via scan-qrcode-then-goto-url.
  text = req.query.check
  dbkeep= await getAsync 'important'
  if dbkeep isnt '' and text isnt '' and dbkeep is text
    # save this daka-item
    try
      obj = new Date
      desc = obj.toString()
      ms = Date.parse obj 
      ins = await Nohm.factory 'daily'
      ins.property
        # if client has 2 difference browser,one for socketio,and one for qrcode-parser.how the 'alias' value is fit?
        alias: req.query.alias # or req.session.auth.alias 
        utc_ms: ms
        whatistime: desc 
        browser: req.headers["user-agent"] 
        category:req.query.mode # 'entry' or 'exit' mode
      await ins.save()
      # notice admin with user's success.
      # the .js file include socket,if code=0,socket.emit 'code','0'
      return res.render 'user-daka-response-success',{code:'0',title:'login Result',status:'打卡成功',user:req.query.alias}
    catch error
      console.log 'error',error
      # notice admin with user's failure.
      # the .js file include socket,if code=-1,socket.emit 'code','-1'
      # show db errors
      return res.render 'user-daka-response-failure',{title:'daka failure','reason':ins.errors,code:'-1',user:req.query.alias,status:'数据库错误，打卡失败。'}
  else
    return res.render 'user-daka-response-failure',{title:'daka failure',status:'打卡失败',code:'-1',reason:'超时或身份验证无效',user:req.query.alias}
    
# start-point-admin 
app.get '/admin/daka',(req,res)->
  if req.session?.auth?.role isnt 'admin'
    req.session.referrer = '/admin/daka'
    res.redirect 303,'/admin/login'
  else
    res.render 'admin-daka',{title:'Admin Console'}
 
app.get '/admin/login',(req,res)->
  # pagejs= /mine/mine-admin-login.js
  res.render 'admin-login',{title:'Fill Authentication Form'}

app.get '/admin/admin-update-password',(req,res)->
  res.render 'admin-update-password',{title:'Admin-Update-Password'}

app.put '/admin/logout',(req,res)->
  role = req.session?.auth?.role
  if role is 'admin'
    req.session.auth.role = 'unknown'
    req.session.auth.alias = 'noname'
    res.json {reason:'',status:'logout success'}
  else
    # notice that,if client logout failure,not change its role and alias
    res.json {reason:'no this account or role isnt admin.',status:'logout failure'}

app.post '/admin/admin-update-password',(req,res)->
  {oldpassword,newpassword,alias} = req.body
  items = await accountModel.findAndLoad {alias:alias}
  if items.length is 0
    res.json 'no found!'
  else
    item = items[0]
    dbkeep = item.property 'password'
    if dbkeep is hashise oldpassword
      # update this item's password part
      item.property 'password',hashise newpassword
      try
        item.save()
      catch error
        return res.json item.error 
      return res.json 'Update Password For Admin.'
    else #password is mismatches.
      return res.json 'Mismatch your oldpassword,check it.'
    
app.get '/admin/register-user',(req,res)->
  if req.session?.auth?.role isnt 'admin'
    res.redirect 302,'/admin/login'
  else
    res.render 'admin-register-user',{title:'Admin-Register-User'}

app.post '/admin/register-user',(req,res)->
  {alias,password} = req.body
  if ! filter alias or ! filter password
    return res.json 'Wrong:User Name(alias) contains invalid character(s).'
  ins = await Nohm.factory 'account' 
  ins.property
    alias:alias
    role:'user'
    initial_timestamp:Date.parse new Date
    # always remember:hashise!!
    password: hashise password 
  try
    await ins.save()
    res.json 'Register User - ' + alias
  catch error
    res.json  ins.errors 

# db operator:FIND(superuser,admin are need list all tickets)
# db operator:ADD
app.all '/admin/create-new-ticket',(req,res)->
  if req.session?.auth?.role isnt 'admin'
    req.session.referrer = '/admin/create-new-ticket'
    return res.redirect 303,'/admin/login'
  # redis instance already exists - 'redis'
  if req.method is 'GET'
    res.render 'admin-create-new-ticket',{alias:req.session.auth.alias,title:'Admin-Create-New-Ticket'} 
  else # POST
    # let npm-formidable handles
    formid = new formidable.IncomingForm
    formid.uploadDir = TICKET_MEDIA_ROOT
    formid.keepExtensions = true
    formid.maxFileSize = 20 * 1024 * 1024 # update to 200M,for video
    _save_one_ticket req,res,formid,redis
    
app.all '/admin/edit-ticket/:keyname',(req,res)->
  if req.session?.auth?.role isnt 'admin'
    req.session.referrer = '/admin/edit-ticket/' + req.params.keyname
    return res.redirect 303,'/admin/login'
  keyname = req.params.keyname
  if req.method is 'GET'
    # because it first from a inner-click,so not worry about if key exists.
    item = await hgetallAsync keyname
    res.render 'admin-edit-ticket-form',{keyname:keyname,title:'admin edit ticket',item:item}
  else if req.method is 'POST'
    item = await hgetallAsync keyname
    options = item # todo.
    ticket_id = item.ticket_id
    formid = new formidable.IncomingForm
    formid.uploadDir = TICKET_MEDIA_ROOT
    formid.keepExtensions = true
    formid.maxFileSize = 20 * 1024 * 1024 # update maxFileSize to 200M if supports video
    formid.parse req,(formid_err,fields,files)->
      if formid_err
        return res.render 'admin-save-ticket-no-good.pug',{title:'No Save',reason:formid_err.message}
      for k,v of fields
        if k isnt 'original_uri' 
          options[k] = v 
      if files.media.size is 0 
        bool = fs.existsSync files.media.path
        if bool
          fs.unlinkSync files.media.path
        else
          console.log 'files.media.path illegel.'
      if files.media.size isnt 0 
        media_url = files.media.path
        realpath = path.join(STATIC_ROOT,'tickets',fields.original_uri.replace(/.*\/(.+)$/,"$1"))
        if fields.original_uri
          fs.unlinkSync(path.join(STATIC_ROOT,'tickets',fields.original_uri.replace(/.*\/(.+)$/,"$1")))
        media_url = '/tickets/' + media_url.replace /.*\/(.+)$/,"$1" 
        options['media'] = media_url
        options['media_type'] = files.media.type
      # 检查category是否变了
      if not (new RegExp(fields.category)).test keyname
        await delAsync keyname
        keyname = keyname.replace /hash:(.+)(:.+)$/,'hash:' + fields.category + '$2' 
        
      # update this ticket
      redis.hmset keyname,options,(err,reply)->
        if err
          return res.render 'admin-save-ticket-no-good.pug',{title:'No Save',reason:err.message}
        else 
          return res.render 'admin-save-ticket-success.pug',{ticket_id:ticket_id,reply:reply,title:'Updated!'}

  else 
    res.send 'No Clear.'

# in fact,it is 'update-ticket',the query from route /admin/ticket-detail/:id
app.post '/admin/create-new-comment',(req,res)->
  {keyname,comment} = req.body
  lines = comment.replace(/\r\n/g,'\n').split('\n')
  paras = ''
  for line in lines 
    paras += '<p>' + line + '</p>' 
  comment_str = [
      '<blockquote class="blockquote text-center"><p>'
      paras 
      '</p><footer class="blockquote-footer"> <cite>发表于：</cite>'
      new Date()
      '<button type="button" class="ml-2 btn btn-light" data-toggle="popover" data-placement="bottom" data-content="'
      req.header("user-agent")
      '" title="browser infomation"> browser Info </button></footer></blockquote>'
    ].join '' 
  
  redis.hget keyname,'reference_comments',(err1,listkey)->
    if err1 
      return res.json {replyText:'no good,reason:' + err1.message} 
    redis.lpush listkey,comment_str,(err2)->
      if err2
        return res.json {replyText:'no good,reason:' + err2.message}
      else
        redis.hincrby keyname,'visits',1,(err3)-> 
          if err3
            return res.json {replyText:'no good,reason:' + err3.message}
          else
            return res.json {replyText:'Good Job'} 

# db operator:DELETE
app.delete '/admin/del-one-ticket',(req,res)->
  if req.session?.auth?.role isnt 'admin'
    req.session.referrer = '/admin/del-one-ticket'
    return res.redirect 303,'/admin/login'
  else
    # check if has 'with-media' flag.
    {keyname,with_media} = req.query
    if with_media is 'true'
      # 'media' is media's path
      redis.hget keyname,'media',(err,reply)->
        # remember that : media url !== fs path
        media = path.join __dirname,'public',reply
        # check if media path exists yet.
        fs.stat media,(err,stats)->
          intReply = await delAsync keyname 
          if err
            # just del item from redis db,file system del failure.
            res.send '删除条目' + intReply + '条,media file not clear,because:' +  err.message
          else
            fs.unlink media,(err2)->
              if err2 is null
                res.send '删除条目' + intReply + '条,media file clear.'
              else
                res.send '删除条目' + intReply + '条,media file not clear,because:' +  err2.message
    else
      try
        # del its referencing comments 
        referencing_comments = await hgetAsync keyname,'reference_comments' 
        referenceDeleted = await delAsync referencing_comments 
        keyDeleted = await delAsync keyname 
        res.send '删除条目' + keyDeleted + '条,删除评论' + referenceDeleted +  '条.'
      catch error
        res.send error.message
     
      
app.get '/admin/del-all-tickets',(req,res)->
  if req.session?.auth?.role isnt 'admin'
    req.session.referrer = '/admin/del-all-tickets'
    return res.redirect 303,'/admin/login'
  else
    redis.keys TICKET_PREFIX + ':hash:*',(err,list)->
      for item in list
        await delAsync item
      # at last ,report to client.
      res.render 'admin-del-all-tickets'

# 投稿
app.post '/admin/contribute',(req,res)->
  if req.session?.auth?.role isnt 'admin'
    return res.json 'auth error.'
  {keyname,to_address,to_port} = req.body
  to_port = '80' if to_port is '' 
  if not keyname or not to_address 
    return res.json 'invalidate data.'
  prefix_url = 'http://' + to_address + ':' + to_port
  # retrieve item 
  request = require 'superagent'
  agent = request.agent()
  try
    o = await hgetallAsync keyname
  catch error
    return res.json 'DB Operator Error.'
  agent.post prefix_url+ '/admin/login'
    .type 'form'
    .send {'alias':'agent'}
    .send {'password':'1234567'} # solid password for this task.
    .end (err,reply)->
      if err 
        return res.json err 
      # TODO if not match admin:password,err is null,but something is out of your expecting.
      if not o.media 
        agent.post prefix_url + '/admin/create-new-ticket'
          .send {
            'admin_alias':'agent'
            'title':o.title
            'ticket':o.ticket
            'client_time':o.client_time
            'category':o.category
            'visits':o.visits
            'agent_post_time':(new Date()).toISOString()
          }
          .end (err,resp)->
            if err
              return res.json err
            res.json resp.status
      else # has media attribute
        attachment = path.join __dirname,'public',o.media
        agent.post  prefix_url + '/admin/create-new-ticket'
          .field 'alias','agent'
          .field 'title',o.title
          .field 'ticket',o.ticket
          .field 'client_time',o.client_time
          .field 'category',o.category
          .field 'visits',o.visits
          .field 'agent_post_time',(new Date()).toISOString()
          .attach 'media',attachment
          .end (err,resp)-> 
            if err
              return res.json err
            res.json resp.status

app.get '/admin/get-ticket-by-id/:id',(req,res)->
  ticket_id = req.params.id
  if req.session?.auth?.role isnt 'admin'
    req.session.referrer = '/admin/get-ticket-by-id/' + ticket_id
    return res.redirect 303,'/admin/login'
  redis.keys TICKET_PREFIX + ':hash:*:' + ticket_id,(err,list)->
    if err
      res.json {status:'Error Occurs While Retrieving This Id.'}
    else
      if list.length is 0
        res.render 'admin-ticket-no-found.pug',{status:'This Ticket Id No Found'}
      else
        item = await hgetallAsync list[0]
        item.comments =  await lrangeAsync item.reference_comments,0,-1
        # add for template - 'views/admin-ticket-detail.pug'(20190910 at hanjie he dao)
        item.keyname = list[0] 
        # add 1 to 'visits'
        redis.hincrby list[0],'visits',1,(err,num)->
          if err is null
            res.render 'admin-ticket-detail',{title:'#' + item.ticket_id + ' Detail Page',item:item}
          else
            res.json 'Error Occurs During DB Manipulating.'
   
app.post '/admin/ticket-details',(req,res)->
  ticket_id = req.body.ticket_id
  redis.keys TICKET_PREFIX + ':hash:*:' + ticket_id,(err,list)->
    if err
      res.json {status:'Error Occurs While Retrieving This Id.'}
    else
      if list.length is 0
        res.render 'admin-ticket-no-found.pug',{status:'This Ticket Id No Found'}
      else
        # add 1 to 'visits'
        redis.hincrby list[0],'visits',1,(err,num)->
          if err is null
            item = await hgetallAsync list[0]
            item.keyname = list[0]
            item.comments =  await lrangeAsync item.reference_comments,0,-1
            #res.render 'admin-newest-ticket.pug',{title:'Detail Page #' + ticket_id,records:[item]}
            res.redirect 302,'/admin/get-ticket-by-id/' + ticket_id
          else
            res.json 'Error Occurs During DB Manipulating.'

app.all '/admin/full-tickets',(req,res)->
  if req.session?.auth?.role isnt 'admin'
    req.session.referrer = '/admin/full-tickets'
    return res.redirect 303,'/admin/login'
  if req.method is 'GET' 
    redis.scan [0,'match','ticket:hash*','count','29'],(err,list)->
      items = []
      for key in list[1]
        item = await hgetallAsync key 
        items.push item
      res.render 'admin-full-tickets.pug',{next:list[0],items:items,title:'Full Indexes'}
  else if req.method is 'POST'
    redis.scan [req.body.nextCursor,'match','ticket:hash*','count','29'],(err,list)->
      if err
        res.json 'in case IS POST AND SCAN OCCURS ERROR.'
      else
        items = []
        for key in list[1]
          item = await hgetallAsync key 
          items.push item
        res.json {items:items,next:list[0]}
  else
    res.json 'unknown.'

app.get '/admin/category-of-tickets/:category',(req,res)->
  category = req.params.category
  if req.session?.auth?.role isnt 'admin'
    req.session.referrer = '/admin/category-of-tickets/' + category
    return res.redirect 303,'/admin/login'
  else
    keyname =  TICKET_PREFIX + ':hash:' + category + '*'
    records = await _retrieves keyname,(a,b)->b.ticket_id - a.ticket_id
    if records.length > 20
      records = records[0...20]
    res.render 'admin-newest-ticket.pug',{records:records,title:'分类列表:'+category + 'top 20'}
app.get '/admin/visits-base-tickets',(req,res)->
  if req.session?.auth?.role isnt 'admin'
    req.session.referrer = '/admin/visits-base-tickets/'
    return res.redirect 303,'/admin/login'
  else
    keyname =  TICKET_PREFIX + ':hash:*'
    records = await _retrieves keyname,(a,b)->b.visits - a.visits
    if records.length > 20
      records = records[0...20]
    res.render 'admin-newest-ticket.pug',{records:records,title:'top 20 visits tickets'}
  
app.get '/admin/newest-ticket',(req,res)->
  if req.session?.auth?.role isnt 'admin'
    req.session.referrer = '/admin/newest-ticket'
    return res.redirect 303,'/admin/login'
  else
    keypattern =  TICKET_PREFIX + ':hash:*'
    # at zhongnan hospital,fixed below await-func(inner help function - '_retrieves'
    records = await _retrieves(keypattern,((a,b)->b.ticket_id - a.ticket_id))
    # retrieve top 20 items.
    if records.length > 20
      records = records[0...20]
    return res.render 'admin-newest-ticket.pug',{'title':'list top 20 items.',records:records}
  
app.post '/admin/enable-user',(req,res)->
  id = req.body.id
  try
    ins = await Nohm.factory 'account',id
    ins.property 'isActive',true
    await ins.save()
    res.json {code:0,message:'update user,now user in active-status.' }
  catch error
    reason = {
      thrown: error
      nohm_said:ins.errors
    }
    res.json {code:-1,reason:reason}
    
app.post '/admin/disable-user',(req,res)->
  id = req.body.id
  try
    ins = await Nohm.factory 'account',id
    ins.property 'isActive',false
    await ins.save()
    res.json {code:0,message:'update user,now user in disable-status.' }
  catch error
    reason = {
      thrown: error
      nohm_said:ins.errors
    }
    res.json {code:-1,reason:reason}
    
app.put '/admin/del-user',(req,res)->
  ins = await Nohm.factory 'account'
  # req.query.id be transimit from '/admin/list-users' page.  
  id = req.body.id
  ins.id = id
  try
    await ins.remove()
  catch error
    return res.json {code:-1,'reason':JSON.stringify(ins.errors)}
  return res.json {code:0,'gala':'remove #' + id + ' success.'}
   
app.post '/admin/login',(req,res)->
  {itisreferrer,alias,password} = req.body
  itisreferrer = itisreferrer or '/admin/login-success' 
  # filter alias,and password
  isInvalid = ( !(filter alias) or !(filter password) )
  if isInvalid 
    return res.render 'admin-login-failure',{title:'Login-Failure',reason:'表单中含有非法字符.'} 
  # initial session.auth
  initSession req
  # first check if exists this alias name?
  # mobj is 'match stats object'
  mobj = await matchDB accountModel,alias,'admin',password
  if mobj.match_result 
    # till here,login data is matches.
    updateAuthSession req,'admin',alias
    res.redirect 303,itisreferrer
  else
    updateAuthSession req,'unknown','noname'
    res.render 'admin-login-failure' ,{title:'Login-Failure',reason:'管理员登录失败，原因：帐户不存在或者帐户被临时禁用或者帐户名与口令不匹配。'}

app.get '/admin/login-success',(req,res)->
  res.render 'admin-login-success.pug',{title:'Administrator Role Entablished'}

app.get '/admin/checkout-daka',(req,res)->
  if req.session?.auth?.role isnt 'admin'
    req.session.referrer = '/admin/checkout-daka'
    return res.redirect 303,'/admin/login'
  # query all user's name
  inss = await accountModel.findAndLoad {role:'user'} 
  aliases = ( ins.property('alias') for ins in inss )
  res.render 'admin-checkout-daka',{aliases:aliases,title:'Checkout-One-User-DaKa'}

# route /daka database interaction
app.get '/daka/one',(req,res)->
  {user,range} = req.query
  ids = await dakaModel.find {alias:user,utc_ms:{min:0}}
  sorted = await dakaModel.sort {'field':'utc_ms'},ids
  hashes = []
  for id in sorted 
    ins = await dakaModel.load id
    hashes.push ins.allProperties() 
  res.json hashes 

app.get '/admin/list-user-daka',(req,res)->
  alias = req.query.alias
  if ! alias 
    return res.json 'no special user,check and redo.'
  if not filter alias
    return res.json 'has invalid char(s).'
  # first,check role if is admin
  if req.session?.auth?.role isnt 'admin'
    req.session.referrer = '/admin/list-user-daka?alias=' +  alias
    return res.redirect 303,'/admin/login'
  inss = await dakaModel.findAndLoad alias:alias
  result = []
  for ins in inss
    obj = ins.allProperties()
    result.push obj 
  res.render 'admin-list-user-daka',{alias:alias,title:'List User DaKa Items',data:result}

app.get '/admin/list-users',(req,res)->
  if req.session?.auth?.role isnt 'admin' 
    req.session.referrer = '/admin/list-users'
    return res.redirect 303,'/admin/login'
  inss = await accountModel.findAndLoad({'role':'user'})
  results = [] 
  inss.forEach (one)->
    obj = {}
    obj.alias = one.property 'alias'
    obj.role = one.property 'role'
    obj.initial_timestamp = one.property 'initial_timestamp'
    obj.password = one.property 'password'
    obj.isActive = one.property 'isActive'
    obj.id = one.id
    results.push obj 
  res.render 'admin-list-users',{title:'Admin:List-Users',accounts:results}

app.get '/superuser/list-admins',(req,res)->
  if req.session?.auth?.role isnt 'superuser'
    req.session.referrer = '/superuser/list-admins'
    return res.redirect 303,'/superuser/login'
  inss = await accountModel.findAndLoad {'role':'admin'}  
  results = [] 
  inss.forEach (one)->
    obj = {}
    obj.alias = one.property 'alias'
    obj.role = one.property 'role'
    obj.initial_timestamp = one.property 'initial_timestamp'
    obj.password = one.property 'password'
    obj.id = one.id
    results.push obj 
  res.render 'superuser-list-admins',{title:'List-Administrators',accounts:results}

app.get '/superuser/list-tickets/:category',(req,res)->
  pattern = [TICKET_PREFIX,'hash',req.params.category,'*'].join ':'
  redis.keys pattern,(err,keys)->
    # this is a good sample about redis-multi way.maybe multi is perfom better than hgetallAsync.
    list = redis.multi()
    for key in keys
      list.hgetall key
    list.exec (err,replies)->
      if err
        return res.json err
      else 
        return res.render 'superuser-list-tickets',{title:'list tickets',tickets:replies} 

app.put '/superuser/del-admin',(req,res)->
  ins = await Nohm.factory 'account'
  # req.query.id be transimit from '/superuser/list-admins' page.  
  id = req.query.id
  ins.id = id
  try
    await ins.remove()
  catch error
    return res.json {code:-1,'reason':JSON.stringify(ins.errors)}
  return res.json {code:0,'gala':'remove #' + id + ' success.'}
   
app.all '/superuser/daka-complement',(req,res)->
  if req.session?.auth?.role isnt 'superuser'
    req.session.referrer = '/superuser/daka-complement'
    return res.redirect 303,'/superuser/login'
  if req.method is 'POST'
    # client post via xhr,so server side use 'formidable' module
    formid = new formidable.IncomingForm
    formid.parse req,(err,fields,files)->
      if err
        res.json {code:-1} 
      else
        # store
        objs = convert fields 
        responses = []
        for obj in objs #objs is an array,elements be made by one object
          response = await complement_save obj['combo'],obj      
          responses.push response
        # responses example:[{},[{},{}],{}...]
        res.json responses
  else
    res.render 'superuser-daka-complement',{title:'Super User Daka-Complement'}

app.get '/superuser/login',(req,res)->
  # referrer will received from middle ware
  res.render 'superuser-login.pug',{title:'Are You A Super?'}

app.get '/superuser/login-success',(req,res)->
  res.render 'superuser-login-success.pug',{title:'Super User Login!'}

app.post '/superuser/login',(req,res)->
  # initial sesson.auth
  initSession req
  {password,itisreferrer} = req.body
  hash = sha256 password
  if hash is superpass
    updateAuthSession req,'superuser','superuser'
    if itisreferrer
      res.redirect 303,itisreferrer
    else
      res.redirect 301,'/superuser/login-success'
  else
    updateAuthSession req,'unknown','noname'
    res.json {staus:'super user login failurre.'}
  

app.get '/superuser/register-admin',(req,res)->
  if req.session?.auth?.role isnt 'superuser'
    res.redirect 302,'/superuser/login'
  else
    res.render 'superuser-register-admin',{defaultValue:'1234567',title:'Superuser-register-admin'}

app.get '/superuser/delete-all-daka-items',(req,res)->
  if req.session?.auth?.role isnt 'superuser'
    return res.json 'wrong:must role is superuser.'
  # delete all daka items,be cafeful.
  multi = redis.multi()
  redis.keys DAKA_WILDCARD,(err,keys)->
    for key in keys
      multi.del key
    multi.exec (err,replies)->
      res.json replies 

app.post '/superuser/register-admin',(req,res)->
  {adminname} = req.body
  if ! filter adminname
    return res.json 'Wrong:Admin Name(alias) contains invalid character(s).'
  ins = await Nohm.factory 'account' 
  ins.property
    alias:adminname
    role:'admin'
    initial_timestamp:Date.parse new Date
    password: hashise '1234567' # default password. 
  try
    await ins.save()
    res.json 'Saved.'
  catch error
    res.json  ins.errors 

app.get '/no-staticify',(req,res)->
  # listen radio(voa&rfa mandarin)
  fs.readdir path.join(STATIC_ROOT,'audioes'),(err,list)->
    if err is null
      audio_list = []
      for item in list
        realpath = path.join STATIC_ROOT,'audioes',item
        if (fs.statSync realpath).isFile()
          audio_list.push path.join '/audioes',item
      res.render 'no-staticify',{title:'list audioes',list:audio_list}
    else
      res.render 'no-staticify-failure',{title:'you-see-failure',error_reason:err.message}

app.delete '/remove-readed-audio',(req,res)->
  if req.body.data
    uri = path.join 'public',req.body.data
    bool = fs.existsSync uri
    if bool
      fs.unlinkSync uri
      res.json {status:'has deleted.'}
    else
      res.json {status:'no found'}
  else
    res.json {status:'not good'}

# during learn css3,svg..,use this route for convient.
app.use '/staticify/:viewname',(req,res)->
  res.render 'staticify/' + req.params.viewname,{title:'it is staticify page'}
 
app.use (req,res)->
  res.status 404
  res.render '404'
app.use (err,req,res,next)->
  console.error 'occurs 500 error. [[ ' + err.stack + '  ]]'
  res.type 'text/plain'
  res.status 500
  res.send '500 - Server Error!'
if require.main is module
  server = http.Server app
  server.listen 3003,->
    console.log 'server running at port 3003;press Ctrl-C to terminate.'
else
  module.exports = app 

# initSession is a help function
initSession = (req)->
  if not req.session?.auth
    req.session.auth = 
      alias:'noname'
      counter:0
      tries:[]
      matches:[]
      role:'unknown'    
  null

# updateAuthSession is a help function
# this method be invoked by {user|admin|superuser}/login (post request)
updateAuthSession = (req,role,alias)->
  timestamp = new Date
  counter = req.session.auth.counter++
  req.session.auth.tries.push 'counter#' + counter + ':user try to login at ' + timestamp
  req.session.auth.role = role 
  req.session.auth.alias = alias 
  if role is 'unknown'
    req.session.auth.matches.push '*Not* Matches counter#' + counter + ' .'  
  else
    req.session.auth.matches.push 'Matches counter#' + counter + ' .'  
   

# hashise is a help function.
hashise = (plain)->
  hash = crypto.createHash 'sha256'
  hash.update plain
  hash.digest 'hex' 
 
# filter is a help function
filter = (be_dealt_with)->
  # return true is safe,return false means injectable.
  if not be_dealt_with
    return false
  return not /\W/.test be_dealt_with

# matchDB is a help function 
# *Notice that* invoke this method via "await <this>"
matchDB = (db,alias,role,password)->
  # db example 'accountModel'
  items = await db.findAndLoad {'alias':alias}
  if items.length is 0 # means no found.
    return false
  else
    item = items[0]
    dbpassword =  item.property 'password'
    dbrole = item.property 'role'
    isActive = item.property 'isActive'
    warning = ''
    if dbpassword is '8bb0cf6eb9b17d0f7d22b456f121257dc1254e1f01665370476383ea776df414'
      warning = 'should change this simple/initial/templory password immediately.'
    match_result = (isActive) and ((hashise password) is dbpassword)  and (dbrole is role) 
    return {match_result:match_result,warning:warning}

# for authenticate super user password.
sha256 = (plain)->
  crypto.createHash 'sha256'
    .update plain
    .digest 'hex'

# help func convert,can convert formidable's fields object to an object arrary(for iterator store in redis).
convert = (fields)->
  results = []
  for i,v of fields
    matched = i.match /(\D*)(\d*)$/ 
    pre = matched[1]
    post = matched[2] 
    if (post in Object.keys(results)) is false
      results[post] = {}
    results[post][pre] = v
  results

# help function - complement_save()
# complement_save handle single object(one form in client side).
complement_save = (option,fieldobj)->
  # option always is uploaded object's field - option
  response = undefined 
  # inner help function - single_save()
  single_save = (standard)->
    ins = await Nohm.factory 'daily'
    ins.property standard 
    try
      await ins.save()
    catch error
      console.dir error
      return {'item-id':ins.id,'saved':false,reason:ins.errors}
    return {'item-id':ins.id,'saved':true}
  switch option
    when 'option1'
      standard = 
        alias:fieldobj.alias
        utc_ms:Date.parse fieldobj['first-half-']
        whatistime:fieldobj['first-half-']
        dakaer:'superuser'
        category:'entry' 
        browser:req.headers['user-agent']
      response = await single_save standard
    when 'option2'
      standard = 
        alias:fieldobj.alias
        utc_ms:Date.parse fieldobj['second-half-']
        whatistime:fieldobj['second-half-']
        dakaer:'superuser'
        category:'exit' 
        browser:req.headers['user-agent']
      response = await single_save standard
    when 'option3'
      standard1 = 
        alias:fieldobj.alias
        utc_ms:Date.parse fieldobj['first-half-']
        whatistime:fieldobj['first-half-']
        dakaer:'superuser'
        browser:req.headers['user-agent']
        category:'entry' 
      standard2 = 
        alias:fieldobj.alias
        utc_ms:Date.parse fieldobj['second-half-']
        whatistime:fieldobj['second-half-']
        dakaer:'superuser'
        browser:req.headers['user-agent']
        category:'exit' 
      # save 2 instances.
      response1 = await single_save standard1
      response2 = await single_save standard2
      response = [response1,response2]
    else
      response = {code:-1,reason:'unknow status.'}
  response

# help function - '_save_one_ticket'
_save_one_ticket = (req,res,form,redis)->
  form.parse req,(err,fields,files)->
    if err
      return res.render 'admin-save-ticket-no-good.pug',{title :'No Save',reason:err.message}
    options = ['visits','0','urge','0','resolved','false']
    for k,v of fields
      options = options.concat [k,v] 
    if files.media and files.media.size is 0 
      fs.unlinkSync files.media.path
    if files.media and files.media.size isnt 0 
      media_url = files.media.path
      # for img or other media "src" attribute,the path is relative STATIC-ROOT.
      media_url = '/tickets/' + media_url.replace /.*\/(.+)$/,"$1" 
      options = options.concat  ['media',media_url,'media_type',files.media.type]
    # store this ticket
    redis.incr (TICKET_PREFIX + ':counter'),(err,number)->
      if err isnt null # occurs error.
        return res.json 'Occurs Error While DB Operation.' + err.message
      keyname = [TICKET_PREFIX,'hash',fields.category,number].join ':'
      options = options.concat ['ticket_id',number,'reference_comments','comments-for-' + number]
      redis.hmset keyname,options,(err,reply)->
        if err
          return res.json 'Occurs Error During Creating,Reason:' + err.message
        else 
          # successfully
          return res.render 'admin-save-ticket-success.pug',{ticket_id:number,reply:reply,title:'Stored Success'}

# help function - 'retrieves',for retrieves ticket by its first argument.
_retrieves = (keyname,sortby)->
  promise = new Promise (resolve,reject)-> 
    redis.keys keyname,(err,list)->
      records = []
      for item in list 
        record =  await hgetallAsync item
        bool = await existsAsync record.reference_comments
        if bool 
          comments = await lrangeAsync record.reference_comments,0,-1
          # give new attribute 'comments'
          record.comments = comments
        else
          record.comments = [] 
        # keyname 将用于$.ajax {url:'/admin/del-one-ticket?keyname=' + keyname....
        record.keyname = item
        records.push record
      #sorting before output to client.
      records.sort sortby
      resolve records
  return promise
