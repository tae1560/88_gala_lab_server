# coding: utf-8

namespace :server do
  task :start => :environment do

    class UserInformation
      attr_accessor :io, :enemy_io, :user

      def to_json
        json_data = {}
        json_data["user"] = self.user.inspect
        return json_data
      end
    end

    class Server

    end
    def initialize
      puts "initialize"

      @@functions = {} # type, lambda
      @@logon_queue = {} # id, user_information
      @@waiting_queue = [] # user_information

      make_functions
    end
    def make_functions
      # 1. 무작위게임 신청
      @@functions["matching_request"] = lambda{|user_information, json_data|

        unless @@waiting_queue.include? user_information
          @@waiting_queue.push user_information
        end

        if @@waiting_queue.length >= 2
          #matching 0, 1
          user_information1 = @@waiting_queue[0]
          user_information2 = @@waiting_queue[1]

          @@waiting_queue.delete user_information1
          @@waiting_queue.delete user_information2

          user_information1.enemy_io = user_information2.io
          user_information2.enemy_io = user_information1.io

          data = {"type" => "matching_request", "user_information" => user_information1.to_json}
          user_information1.io.puts data.to_s

          data = {"type" => "matching_request", "user_information" => user_information2.to_json}
          user_information2.io.puts data.to_s
        end
      }


      # 스킬 공격
      @@functions["attack_skill"] = lambda { |user_information, json_data|
        data = {"type" => "attack_skill", "user_information" => user_information1.to_json}
        user_information.enemy_io.puts data.to_s
      }


      # 테스트 스킬 공격
      @@functions["test_attack_skill"] = lambda { |user_information, json_data|
        debug "client data : #{json_data.to_s}"

        data = {"type" => "attack_skill", "skill_type" => json_data["skill_type"], "user_information" => user_information.to_json}
        puts data.to_s

        user_information.io.puts data.to_s
      }


      # 친구 목록 요청
      @@functions["request_friends"] = lambda { |user_information, json_data|
        debug "client data : #{json_data.to_s}"

        users = []

        User.find_each do |user|
          current_user = {}
          current_user["id"] = user.login_id
          current_user["character"] = user.character
          current_user["number_of_combo"] = user.number_of_combo
          current_user["number_of_wins"] = user.number_of_wins

          if @@logon_queue[user.id]
            current_user["logon"] = 1
          else
            current_user["logon"] = 0
          end

          users.push current_user
        end

        data = {"type" => "request_friends", "friends" => users.to_s}
        debug "server data : #{json_data.to_s}"

        user_information.io.puts data.to_s
      }


      # TODO
      # 1. 무작위게임 신청
      # 2. 친구와 게임 신청
      # 3. 친구와 게임 수락
      # 4.



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
              else
                result["status"] = "failed"
              end

              io.puts result.to_s

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
              else
                result["status"] = "failed"
                result["message"] = user.errors.full_messages
              end

              io.puts result.to_s

              return user
            end
          end
        rescue
          bt = $!.backtrace * "\n  "
          ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush
        end

      end
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
      # 사용자 정보를 받는다.
      user = doLogin io
      debug "user = #{user.inspect}"

      # login validation
      if user and user.persisted? and @@logon_queue[user.id] == nil
        user_information = UserInformation.new
        user_information.user = user
        user_information.io = io
        @@logon_queue[user.id] = user_information

        # 받고 나서 서버 통신 시작
        debug "#{io} has connected"
        loop do
          begin
            # 대기
            reading_socket user_information
          rescue
            bt = $!.backtrace * "\n  "
            ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush
          ensure
            io.close
            break
          end
        end
        debug "#{io} has disconnected"

        @@logon_queue[user.id] = nil
      end
    end


    require 'socket'  # TCPServer

    # initialize
    initialize

    ss = TCPServer.new(1234)

    debug "Server has been started"
    loop {
      Thread.start(ss.accept) { |io|
        client_logic(io)
      }
    }
    debug "Server has been terminated"

  end
end





#waiting_queue.push s
#
#begin
#  while clients.length == 1
#    puts "#{s} start sleep"
#    sleep(1)
#  end
#  puts "ended"
#  s.print "test"
#
#  #while line = s.gets;  # Returns nil on EOF.
#  #  s.print line.inspect
#  #  (s << "You wrote: #{line.inspect}\r\n").flush
#  #  puts line.inspect
#  #
#  #  clients.each do |client|
#  #    client.print "TESMP\n"
#  #  end
#  #end
#rescue
#  bt = $!.backtrace * "\n  "
#  ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush
#ensure
#  s.close
#end
#clients.delete s

#require 'gserver'
#
#class BasicServer < GServer
#  def serve(io)
#    loop do
#      puts "#{io} has connected"
#
#      begin
#        name = get_user_name io
#        puts "name = #{name}"
#
#      rescue
#        bt = $!.backtrace * "\n  "
#        ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush
#      ensure
#        puts "#{io} has disconnected"
#        s.close
#      end
#    end
#  end
#
#  # 먼저 사용자 정보를 받는다.
#  def get_user_name(io)
#    str = ""
#    while line = io.gets;
#      str += line
#      begin
#        data = JSON.parse(str)
#
#        if result.has_key? 'name'
#          return data['name']
#        end
#      rescue
#        bt = $!.backtrace * "\n  "
#        ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush
#      end
#
#    end
#    return nil
#  end
#end
#
#server = BasicServer.new(1234)
#server.start
#puts "Server has been started"
#
#loop do
#  break if server.stopped?
#end
#puts "Server has been terminated"

