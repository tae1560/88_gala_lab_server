# coding: utf-8

is_daemon = false
namespace :server do
  task :start => :environment do
    class UserInformation
      attr_accessor :io, :user, :enemy_user_information, :hp, :attack_queue, :check_completed, :game_over

      def to_json
        UserInformation.to_json self.user
      end

      def self.to_json user
        current_user = {}
        if user
          current_user["id"] = user.login_id
          current_user["character"] = user.character.to_i
          current_user["number_of_combo"] = user.number_of_combo
          current_user["number_of_wins"] = user.number_of_wins
          current_user["max_number_of_wins"] = user.max_number_of_wins
          current_user["total_wins"] = user.total_wins
          current_user["total_loses"] = user.total_loses

          if @@logon_queue[user.id]
            current_user["is_logon"] = 1
          else
            current_user["is_logon"] = 0
          end
        end

        return current_user
      end
    end

    def init
      puts "initialize"

      @@functions = {} # type, lambda
      @@logon_queue = {} # id, user_information
      @@random_matching_waiting_queue = [] # id
      @@friend_matching_waiting_queue = [] # id

      make_functions
    end

    # 클라이언트에서 받은 정보 파싱
    def make_functions
      # 친구 목록 요청
      @@functions["request_friends"] = lambda { |user_information, json_data|
        debug "client data : #{json_data.to_s}"

        users = []

        User.find_each do |user|
          users.push UserInformation.to_json user
        end

        # TODO : sorting 기준
        users.sort!{|x,y| y["number_of_wins"] <=> x["number_of_wins"]}

        data = {"type" => "request_friends", "friends" => users}
        debug "server data : #{JSON.generate data}"
        user_information.io.puts JSON.generate data

        unless @@friend_matching_waiting_queue.include? user_information.user.id
          @@friend_matching_waiting_queue.push user_information.user.id

          debug "@@friend_matching_waiting_queue.push #{user_information.user.id}"
        end
      }

      # 게임 신청
      @@functions["request_matching"] = lambda{|user_information, json_data|
        debug "client data : #{json_data.to_s}"

        # 매칭 되었을때 클라이언트에게 보내는 정보
        send_matching_information_function = lambda{ |user_information1, user_information2|
          user_information1.enemy_user_information = user_information2
          user_information2.enemy_user_information = user_information1

          # initialize hp and queue
          user_information1.hp = @@initial_hp
          user_information2.hp = @@initial_hp
          user_information1.attack_queue = []
          user_information2.attack_queue = []
          user_information1.game_over = false
          user_information2.game_over = false

          # send data to clients
          data = {"type" => "request_matching", "user_information" => user_information2.to_json}
          debug "server data : #{JSON.generate data}"
          user_information1.io.puts JSON.generate data

          data = {"type" => "request_matching", "user_information" => user_information1.to_json}
          debug "server data : #{JSON.generate data}"
          user_information2.io.puts JSON.generate data

          if @@friend_matching_waiting_queue.include? user_information1.user.id
            @@friend_matching_waiting_queue.delete user_information1.user.id
          end
          if @@friend_matching_waiting_queue.include? user_information2.user.id
            @@friend_matching_waiting_queue.delete user_information2.user.id
          end
        }

        if json_data["friend_id"]
          # matching with friend

          # find user
          friend = User.where(:login_id => json_data["friend_id"]).first
          debug "friend.inspect : #{friend.inspect}"

          # not me
          unless friend.id == user_information.user.id
            # current connected user
            if @@friend_matching_waiting_queue.include? friend.id
              send_matching_information_function.call @@logon_queue[friend.id], user_information
            end
          end

        else
          # random matching

          unless @@random_matching_waiting_queue.include? user_information.user.id
            @@random_matching_waiting_queue.push user_information.user.id
          end

          matching_user = []
          while matching_user.size + @@random_matching_waiting_queue.size >= 2
            matching_user_information = @@logon_queue[@@random_matching_waiting_queue.first]
            if matching_user_information
              @@random_matching_waiting_queue.delete matching_user_information.user.id

              matching_user.push matching_user_information
              if matching_user.size >= 2
                user_information1 = matching_user[0]
                user_information2 = matching_user[1]

                matching_user.delete user_information1
                matching_user.delete user_information2

                send_matching_information_function.call user_information1, user_information2
              end
            else
              debug "#{@@random_matching_waiting_queue.first} not in @@logon_queue"
              @@random_matching_waiting_queue.delete @@random_matching_waiting_queue.first
            end
          end
        end
      }


      # 스킬 공격
      @@initial_hp = 100
      @@skill_damages = {"1" => 5, "2" => 10, "3" => 15}
      @@functions["attack_skill"] = lambda { |user_information, json_data|
        # skill_type, skill_time
        debug "client data : #{json_data.to_s}"

        # TODO :
        # 클라이언트에게 데미지정보, 현재체력정보 넘겨주기
        # 1. 스킬 데미지 계산
        # 2. 스킬 시간 기록을 위한 저장
        # 2-1. 클라이언트로부터 네트워크 확인 정보 받기 (그동안의 공격 정보를 받았는지 확인하기 위해)
        # 3. 누가 이겼는지 승리 판단하기
        # 4. 클라이언트에 끝나면 끝났다는 정보 알려주기
        # 5. 승리 정보 DB에 업데이트 하기

        # gameover check
        unless user_information.game_over
          # initialize => request_matching 에서 처리
          # 스킬 데미지 계산 from @@skill_damages
          skill_damage = @@skill_damages[json_data["skill_type"]]
          user_information.enemy_user_information.hp -= skill_damage

          # 스킬 시간 기록을 위한 저장
          user_information.attack_queue.push json_data

          data = {"type" => "attack_skill", "skill_type" => json_data["skill_type"], "user_information" => user_information.to_json}
          debug "server data : #{JSON.generate data}"
          user_information.enemy_user_information.io.puts JSON.generate data


          # 게임 끝 알리기
          if user_information.hp <= 0 or user_information.enemy_user_information.hp <= 0
            # game over
            user_information.check_completed = false
            user_information.enemy_user_information.check_completed = false

            # TODO : 1:1 대전
            # TODO : 게임 끝난 것 예외처리
            # TODO : 로그아웃 기능 추가
            # 사용자에게 네트워크 상태 요청하기
            data = {"type" => "game_end_check"}
            debug "server data : #{JSON.generate data}"
            user_information.io.puts JSON.generate data
            user_information.enemy_user_information.io.puts JSON.generate data

            user_information.game_over = true
            user_information.enemy_user_information.game_over = true
          end
        end
      }

      # 게임 끝 확인
      @@functions["game_end_check"] = lambda { |user_information, json_data|
        debug "client data : #{json_data.to_s}"

        # 응답 확인
        user_information.check_completed = true

        debug user_information.check_completed
        debug user_information.enemy_user_information.check_completed

        debug user_information.user.login_id
        debug user_information.enemy_user_information.user.login_id

        if user_information.check_completed and user_information.enemy_user_information.check_completed
          # 누가 이겼는지 승리 판단하기
          my_damage = 0
          user_information.attack_queue.each do |attack|
            my_damage += @@skill_damages[attack["skill_type"]]
          end

          enemy_damage = 0
          user_information.enemy_user_information.attack_queue.each do |attack|
            enemy_damage += @@skill_damages[attack["skill_type"]]
          end

          winner_user_information = nil
          if my_damage >= @@initial_hp and enemy_damage < @@initial_hp
            # 내가 이긴 경우
            winner_user_information = user_information
          elsif enemy_damage >= @@initial_hp and my_damage < @@initial_hp
            # 적이 이긴 경우
            winner_user_information = user_information.enemy_user_information
          elsif my_damage >= @@initial_hp and enemy_damage >= @@initial_hp
            # 같이 이긴 경우 => 시간체크
            # TODO : 시간체크
            winner_user_information = user_information
          else
            # 에러 케이스
            debug "에러 케이스 in game_end_check"
          end

          if winner_user_information
            # 승리 정보 DB에 업데이트 하기
            # attr_accessible :number_of_wins, :number_of_combo, :name, :max_number_of_wins, :total_wins, :total_loses
            winner_user_information.user.number_of_wins += 1
            winner_user_information.user.total_wins += 1
            if winner_user_information.user.max_number_of_wins < winner_user_information.user.number_of_wins
              winner_user_information.user.max_number_of_wins = winner_user_information.user.number_of_wins
            end
            winner_user_information.user.save

            winner_user_information.enemy_user_information.user.total_loses += 1
            winner_user_information.enemy_user_information.user.number_of_wins = 0
            winner_user_information.enemy_user_information.user.save

            # 클라이언트에 끝나면 끝났다는 정보 알려주기
            data = {"type" => "game_end", "status" => "win", "user_information" => winner_user_information.to_json}
            debug "server data : #{JSON.generate data}"
            winner_user_information.io.puts JSON.generate data

            data = {"type" => "game_end", "status" => "lose", "user_information" => winner_user_information.enemy_user_information.to_json}
            debug "server data : #{JSON.generate data}"
            winner_user_information.enemy_user_information.io.puts JSON.generate data
          end

        end
      }


      # 테스트 스킬 공격
      @@functions["test_attack_skill"] = lambda { |user_information, json_data|
        debug "client data : #{json_data.to_s}"

        data = {"type" => "attack_skill", "skill_type" => json_data["skill_type"], "user_information" => user_information.to_json}
        debug "server data : #{JSON.generate data}"
        user_information.io.puts JSON.generate data
      }

      # login and join
      @@functions["login"] = lambda { |user_information, json_data|
        debug "client data : #{json_data.to_s}"

        result = {"type" => "login"}
        result["status"] = "failed"
        result["message"] = "already logon"

        debug "server data : #{JSON.generate result}"
        user_information.io.puts JSON.generate result
      }

      @@functions["join"] = lambda { |user_information, json_data|
        debug "client data : #{json_data.to_s}"

        result = {"type" => "join"}
        result["status"] = "failed"
        result["message"] = "already logon"

        debug "server data : #{JSON.generate result}"
        user_information.io.puts JSON.generate result
      }

      @@functions["logout"] = lambda { |user_information, json_data|
        debug "client data : #{json_data.to_s}"

        @@logon_queue[user_information.user.id] = nil
        if @@friend_matching_waiting_queue.include? user_information.user.id
          @@friend_matching_waiting_queue.delete user_information.user.id
        end

        if @@random_matching_waiting_queue.include? user_information.user.id
          @@random_matching_waiting_queue.delete user_information.user.id
        end

        result = {"type" => "logout"}
        result["status"] = "success"

        debug "server data : #{JSON.generate result}"
        user_information.io.puts JSON.generate result

        user_information.io.close
      }

    end

    def debug string
      puts string
    end

    # 사용자 정보를 받는다.
    def doLogin(io)
      str = ""
      while line = io.gets;
        begin
          data = JSON.parse(line)

          if data.has_key? 'type'
            if data['type'] == "login"
              id = data["id"]
              password = data["password"]

              user = User.where(:login_id => id).where(:password => password).first

              result = {}
              result["type"] = "login"
              if user
                result["status"] = "success"
                # TODO : UserInformation.to_json user 로 수정하기
                result["user"] = user.to_json
                # 내정보 받아오기
              else
                result["status"] = "failed"
                result["message"] = "id or password is not valid"
              end

              debug "server data : #{JSON.generate result}"
              io.puts JSON.generate result

              return user
            elsif data['type'] == "join"
              id = data["id"]
              password = data["password"]
              character = data["character"]

              result = {}
              result["type"] = "join"
              user = User.new(:login_id => id, :password => password, :character => character)
              if user.save
                result["status"] = "success"
                # TODO : UserInformation.to_json user 로 수정하기
                result["user"] = user.to_json
              else
                result["status"] = "failed"
                result["message"] = user.errors.full_messages
              end

              debug "server data : #{JSON.generate result}"
              io.puts JSON.generate result

              return user
            end
          end
        rescue
          bt = $!.backtrace * "\n  "
          ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush
        end

      end
      io.close
      return nil
    end

    def reading_socket user_information
      while line = user_information.io.gets;
        debug "original_data : #{line}"
        json_data = JSON.parse(line)
        debug "json_data : #{json_data.inspect}"

        type = json_data['type']
        if type
          if @@functions[type]
            @@functions[type].call user_information, json_data
          else
            puts "function #{type} is not implemented"
          end
        end
      end
    end

    # each client
    def client_logic(io)
      debug "#{io} has connected"

      if io
        begin
          puts "begin"

          loop do

            # 사용자 정보를 받는다.
            user = doLogin io
            debug "user = #{user.inspect}"

            # login validation
            if user and user.persisted?
              if @@logon_queue[user.id]
                if @@friend_matching_waiting_queue.include? user.id
                  @@friend_matching_waiting_queue.delete user.id
                end
                if @@random_matching_waiting_queue.include? user.id
                  @@random_matching_waiting_queue.delete user.id
                end
              end
            #  and @@logon_queue[user.id] == nil
              # login
              user_information = UserInformation.new
              user_information.user = user
              user_information.io = io
              @@logon_queue[user.id] = user_information

              # 받고 나서 서버 통신 시작
              reading_socket user_information
            else

            end
          end
        rescue
          puts "rescue"
          bt = $!.backtrace * "\n  "
          ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush
        ensure
          puts "ensure"

          unless io.closed?
            io.close
            debug "#{io} has disconnected - on ensure"
          end

          if user
            @@logon_queue[user.id] = nil
            if @@friend_matching_waiting_queue.include? user.id
              @@friend_matching_waiting_queue.delete user.id
            end
            if @@random_matching_waiting_queue.include? user.id
              @@random_matching_waiting_queue.delete user.id
            end
          end
        end
      end

      if io.closed?
        debug "#{io} has disconnected"
      end
    end

    require 'socket'  # TCPServer
    require 'json'

    # initialize
    init

    ss = TCPServer.new(1234)

    debug "Server has been started"

    if is_daemon
      File.open("test.txt", "w") do | file |
        file.puts $$
        Process.daemon
        file.puts $$
      end
    end



    loop {
      Thread.start(ss.accept) { |io|
        client_logic(io)
      }
    }
    debug "Server has been terminated"

  end

  task :daemon => :environment do
    is_daemon = true
    Rake::Task["server:start"].execute
  end
end