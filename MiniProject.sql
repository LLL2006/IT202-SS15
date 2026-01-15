create database if not exists social_network;
use social_network;

create table users (
    user_id int primary key auto_increment,
    username varchar(50) unique not null,
    password varchar(255) not null,
    email varchar(100) unique not null,
    friends_count int default 0,
    created_at datetime default current_timestamp
);

create table posts (
    post_id int primary key auto_increment,
    user_id int,
    content text not null,
    like_count int default 0,
    created_at datetime default current_timestamp,
    foreign key (user_id) references users(user_id) on delete cascade
);

create table comments (
    comment_id int primary key auto_increment,
    post_id int,
    user_id int,
    content text not null,
    created_at datetime default current_timestamp,
    foreign key (post_id) references posts(post_id) on delete cascade,
    foreign key (user_id) references users(user_id) on delete cascade
);

create table likes (
    user_id int,
    post_id int,
    created_at datetime default current_timestamp,
    primary key (user_id, post_id),
    foreign key (user_id) references users(user_id) on delete cascade,
    foreign key (post_id) references posts(post_id) on delete cascade
);

create table friends (
    user_id int,
    friend_id int,
    status varchar(20) check (status in ('pending', 'accepted')) default 'pending',
    created_at datetime default current_timestamp,
    primary key (user_id, friend_id),
    foreign key (user_id) references users(user_id) on delete cascade,
    foreign key (friend_id) references users(user_id) on delete cascade
);

-- Bài 1: Đăng Ký Thành Viên
create table user_log (
    log_id int primary key auto_increment,
    user_id int,
    action varchar(50),
    log_time datetime default current_timestamp
);

delimiter //
create procedure sp_register_user(
    in p_username varchar(50),
    in p_password varchar(255),
    in p_email varchar(100)
)
begin
    if exists (select 1 from users where username = p_username) then
        signal sqlstate '45000' set message_text = 'lỗi: username đã tồn tại';
    elseif exists (select 1 from users where email = p_email) then
        signal sqlstate '45000' set message_text = 'lỗi: email đã tồn tại';
    else
        insert into users (username, password, email) values (p_username, p_password, p_email);
    end if;
end //
delimiter ;

create trigger tg_after_insert_user
after insert on users
for each row
insert into user_log (user_id, action) values (new.user_id, 'đăng ký tài khoản');

call sp_register_user('user1', 'pass1', 'user1@example.com');
call sp_register_user('user2', 'pass2', 'user2@example.com');
call sp_register_user('user3', 'pass3', 'user3@example.com');

call sp_register_user('user1', 'pass3', 'new@example.com');
call sp_register_user('user4', 'pass4', 'user3@example.com');

select * from users;
select * from user_log;

-- Bài 2: Đăng Bài Viết
create table post_log (
    log_id int primary key auto_increment,
    post_id int,
    user_id int,
    action varchar(50),
    log_time datetime default current_timestamp
);

delimiter //
create procedure sp_create_post(in p_user_id int, in p_content text)
begin
    -- kiểm tra nội dung không được rỗng hoặc chỉ toàn khoảng trắng
    if p_content is null or trim(p_content) = '' then
        signal sqlstate '45000' set message_text = 'lỗi: nội dung không được rỗng';
    else
        insert into posts (user_id, content) values (p_user_id, p_content);
    end if;
end //
delimiter ;

create trigger tg_after_insert_post
after insert on posts
for each row
insert into post_log (post_id, user_id, action) 
values (new.post_id, new.user_id, 'người dùng đăng bài mới');

call sp_create_post(1, 'nội dung bài viết số 1');
call sp_create_post(1, 'nội dung bài viết số 2');
call sp_create_post(1, 'nội dung bài viết số 3');
call sp_create_post(1, 'nội dung bài viết số 4');
call sp_create_post(1, 'nội dung bài viết số 5');

call sp_create_post(1, '');

select * from posts;

-- Bài 3: Thích Bài Viết
alter table posts add column like_count int default 0;

create trigger tg_after_insert_like
after insert on likes
for each row
update posts set like_count = like_count + 1 where post_id = new.post_id;

create trigger tg_after_delete_like
after delete on likes
for each row
update posts set like_count = like_count - 1 where post_id = old.post_id;

insert into likes (user_id, post_id) values (2, 3); 
select post_id, like_count from posts where post_id = 3;

delete from likes where user_id = 2 and post_id = 3; 
select post_id, like_count from posts where post_id = 3; 

-- Bài 4: Gửi Lời Mời Kết Bạn
delimiter //
create procedure sp_send_friend_request(in p_sender_id int, in p_receiver_id int)
begin
    if p_sender_id = p_receiver_id then
        signal sqlstate '45000' set message_text = 'lỗi: không thể tự gửi lời mời cho chính mình';
    elseif exists (select 1 from friends where user_id = p_sender_id and friend_id = p_receiver_id) then
        signal sqlstate '45000' set message_text = 'lỗi: lời mời hoặc quan hệ đã tồn tại';
    else
        insert into friends (user_id, friend_id, status) values (p_sender_id, p_receiver_id, 'pending');
    end if;
end //
delimiter ;

call sp_send_friend_request(1, 2);
call sp_send_friend_request(1, 2);
call sp_send_friend_request(1, 1);

select * from friends;

-- Bài 5: Chấp Nhận Lời Mời Kết Bạn
delimiter //
create procedure sp_accept_friend(
    in p_user_id int, 
    in p_friend_id int
)
begin
    declare exit handler for sqlexception
    begin
        rollback;
        select 'lỗi: không thể chấp nhận kết bạn' as thông_báo;
    end;

    start transaction;
        update friends 
        set status = 'accepted' 
        where user_id = p_user_id and friend_id = p_friend_id;

        insert ignore into friends (user_id, friend_id, status) 
        values (p_friend_id, p_user_id, 'accepted');
    commit;
    
    select 'đã chấp nhận kết bạn và tạo quan hệ đối xứng' as thông_báo;
end //
delimiter ;

call sp_accept_friend(1, 2);

select * from friends;

-- Bài 6: Quản Lý Mối Quan Hệ Bạn Bè
delimiter //
create procedure sp_remove_friend(
    in p_user_id int, 
    in p_friend_id int
)
begin
    declare exit handler for sqlexception
    begin
        rollback;
        select 'lỗi: không thể xóa mối quan hệ bạn bè' as thông_báo;
    end;

    start transaction;
        delete from friends 
        where user_id = p_user_id and friend_id = p_friend_id;

        delete from friends 
        where user_id = p_friend_id and friend_id = p_user_id;
    commit;
    
    select 'đã xóa kết bạn thành công ở cả hai phía' as thông_báo;
end //

delimiter ;

call sp_remove_friend(1, 2);
select * from friends; 

-- Bài 7: Quản Lý Xóa Bài Viết
delimiter //
create procedure sp_delete_post(
    in p_post_id int,
    in p_user_id int
)
begin
    declare exit handler for sqlexception
    begin
        rollback;
        select 'lỗi hệ thống: không thể xóa bài viết.' as thông_báo;
    end;

    if not exists (select 1 from posts where post_id = p_post_id and user_id = p_user_id) then
        select 'lỗi: bài viết không tồn tại hoặc bạn không có quyền xóa' as thông_báo;
    else
        start transaction;
            delete from likes where post_id = p_post_id;
            delete from comments where post_id = p_post_id;
			delete from posts where post_id = p_post_id;
        commit;
        
        select 'đã xóa bài viết và toàn bộ tương tác liên quan thành công' as thông_báo;
    end if;
end //
delimiter ;

call sp_delete_post(3, 1);

-- Bài 8: Quản Lý Xóa Tài Khoản Người Dùng
delimiter //
create procedure sp_delete_user(
    in p_user_id int
)
begin
    declare exit handler for sqlexception
    begin
        rollback;
        select 'lỗi: không thể xóa tài khoản. dữ liệu đã được hoàn tác.' as thông_báo;
    end;

    start transaction;
        delete from likes where user_id = p_user_id;
        delete from comments where user_id = p_user_id;

        delete from likes where post_id in (select post_id from posts where user_id = p_user_id);
        delete from comments where post_id in (select post_id from posts where user_id = p_user_id);

        delete from posts where user_id = p_user_id;

        delete from friends where user_id = p_user_id or friend_id = p_user_id;

        delete from users where user_id = p_user_id;
    commit;

    select 'tài khoản và toàn bộ dữ liệu liên quan đã được xóa vĩnh viễn' as thông_báo;
end //

delimiter ;

call sp_delete_user(1);