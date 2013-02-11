# coding: utf-8

namespace :server do
  task :start => :environment do

    class UserInformation
      attr_accessor :io, :enemy_io, :user

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

          if @@logon_queue[user.id]
            current_user["is_logon"] = 1
          else
            current_user["is_logon"] = 0
          end
        end

        return current_user
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
      @@functions["request_matching"] = lambda{|user_information, json_data|
        debug "client data : #{json_data.to_s}"
        debug "user_information : #{user_information.inspect}"

        unless @@waiting_queue.include? user_information
          debug "@@waiting_queue.include"
          @@waiting_queue.push user_information
        end
        debug "@@waiting_queue : #{@@waiting_queue.inspect}"
        debug "@@waiting_queue : #{@@waiting_queue.length}"

        if @@waiting_queue.length >= 2
          #matching 0, 1
          debug "@@waiting_queue.length >= 2"
          
          user_information1 = @@waiting_queue[0]
          user_information2 = @@waiting_queue[1]

          @@waiting_queue.delete user_information1
          @@waiting_queue.delete user_information2

          user_information1.enemy_io = user_information2.io
          user_information2.enemy_io = user_information1.io

          data = {"type" => "request_matching", "user_information" => user_information1.to_json}
          debug "server data : #{data.to_s}"
          user_information1.io.puts data.to_s

          data = {"type" => "request_matching", "user_information" => user_information2.to_json}
          debug "server data : #{data.to_s}"
          user_information2.io.puts data.to_s
        end
      }


      # 스킬 공격
      @@functions["attack_skill"] = lambda { |user_information, json_data|
        debug "client data : #{json_data.to_s}"

        data = {"type" => "attack_skill", "skill_type" => json_data["skill_type"], "user_information" => user_information.to_json}
        debug "server data : #{data.to_s}"

        user_information.enemy_io.puts data.to_s
      }


      # 테스트 스킬 공격
      @@functions["test_attack_skill"] = lambda { |user_information, json_data|
        debug "client data : #{json_data.to_s}"

        data = {"type" => "attack_skill", "skill_type" => json_data["skill_type"], "user_information" => user_information.to_json}
        debug "server data : #{data.to_s}"

        user_information.io.puts data.to_s
      }


      # 친구 목록 요청
      @@functions["request_friends"] = lambda { |user_information, json_data|
        debug "client data : #{json_data.to_s}"

        users = []

        User.find_each do |user|
          users.push UserInformation.to_json user
        end

        data = {"type" => "request_friends", "friends" => users.to_s}
        debug "server data : #{data.to_s}"

        user_information.io.puts data.to_s
      }


      # TODO
      # 1. 무작위게임 신청
      # 2. 친구와 게임 신청
      # 3. 친구와 게임 수락
      # 4.


      # login and join
      @@functions["login"] = lambda { |user_information, json_data|
        debug "client data : #{json_data.to_s}"

        result = {"type" => "login"}
        result["status"] = "failed"
        result["message"] = "already logon"

        debug "server data : #{result.to_s}"
        user_information.io.puts result.to_s
      }

      @@functions["join"] = lambda { |user_information, json_data|
        debug "client data : #{json_data.to_s}"

        result = {"type" => "join"}
        result["status"] = "failed"
        result["message"] = "already logon"

        debug "server data : #{result.to_s}"
        user_information.io.puts result.to_s
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
      debug "#{io} has connected"
      loop do
        begin
          puts "begin"

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
            reading_socket user_information

            @@logon_queue[user.id] = nil
          end

          # 대기

        rescue
          puts "rescue"
          bt = $!.backtrace * "\n  "
          ($stderr << "error: #{$!.inspect}\n  #{bt}\n").flush

          @@logon_queue[user.id] = nil
        ensure
          puts "ensure"
          @@logon_queue[user.id] = nil
          break
        end
      end
      io.close
      debug "#{io} has disconnected"
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

