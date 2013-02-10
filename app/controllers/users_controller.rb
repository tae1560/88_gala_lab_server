class UsersController < ApplicationController
  def index
    render :json => User.all.inspect
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
