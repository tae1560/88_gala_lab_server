class UsersController < ApplicationController
  def index
    @users = []
    User.find_each do |user|
      user_information = {}
      user_information["id"] = user.login_id
      user_information["character"] = user.character
      user_information["number_of_combo"] = user.number_of_combo
      user_information["number_of_wins"] = user.number_of_wins

      @users.push user_information
    end
    render :json => @users
  end

  def login
    id = params[:id]
    password = params[:password]

    user = User.where(:login_id => id).where(:password => password).first

    result = {}
    if user
      result[:status] = "success"
    else
      result[:status] = "failed"
    end

    render :json => result
  end

  def join
    id = params[:id]
    password = params[:password]
    character = params[:character]

    result = {}

    user = User.new(:login_id => id, :password => password, :character => character)
    if user.save
      result[:status] = "success"
    else
      result[:status] = "failed"
      result[:message] = user.errors.full_messages
    end

    render :json => result
  end
end
