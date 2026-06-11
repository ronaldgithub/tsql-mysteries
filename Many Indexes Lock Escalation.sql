-- How Unused Indexes Hurt - Lock Escalation

exec dbo.DropIndexes;

create index xwho on dbo.users(Reputation);
create index xwhom on dbo.users(Creationdate, Downvotes) include (Age);
create index xwhomst on dbo.users(Age);
create index xwhomstd on dbo.users(Views, Age, AccountId);
create index xwhomstdve on dbo.users(DisplayName) include (age);
create index xwhomstdvely on dbo.users(WebsiteUrl,age);
create index xwhomstdvelyaint on dbo.users(Emailhash,age);
create index xwhomstdvelyainted on dbo.users(Downvotes,age);
-- Na deze 
create index xwhomstdvelyaintedies on dbo.users(AccountId,age);
create index xwhomstdvelyaintediesed on dbo.users(age, Upvotes);
create index xwhomstdvelyaintediesedies on dbo.users(age, Downvotes);
create index xwhomstdvelyaintediesediess on dbo.users(age, id);
create index xwhomstdvelyaintediesediessy on dbo.users(age, DisplayName);
create index xwhomstdvelyaintediesediessyes on dbo.users(age, LastAccessDate);


-- How Unused Indexes Hurt - Lock Escalation
begin tran
update u
set u.Age = 138
from dbo.Users u
where u.reputation = 191;
-- (1556 rows affected)
rollback


-- 
-- How Unused Indexes Hurt - Lock Escalation
-- sp_whoisactive 
-- 52

select wul.request_mode
, wul.locked_object
, wul.resource_type
, sum(wul.total_locks)total_locks
from dbo.vw_WhatsUpLocks wul
where wul.request_session_id = 52
and wul.locked_object is not null
group by wul.request_mode
, wul.locked_object
, wul.resource_type;

/*
request_mode	locked_object	resource_type	total_locks
IX		Users		OBJECT	1
X		Users		KEY		1556
IX		Users		PAGE	1522
*/

/* xwho
request_mode	locked_object	resource_type	total_locks
IX	Users	OBJECT	1
X	Users	KEY		1556
IX	Users	PAGE	1522
*/ 

/* xwhom
request_mode	locked_object	resource_type	total_locks
IX	Users	OBJECT	1
IX	Users	PAGE	2908
X	Users	KEY		3112
*/ 

/* xwhomstdvelyaintedies
Nu werkt de ene querie ook niet meer
request_mode	locked_object	resource_type	total_locks
X	Users	OBJECT	32
*/


select count(*) cnt 
from dbo.Users u
where u.Id = 1 -- Has a reputation of 44.300

select count(*) cnt 
from dbo.Users u
where u.Id = 1767 -- Has a reputation of 191