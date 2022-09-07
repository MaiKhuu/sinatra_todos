# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'

# turn on session, escape html
configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, escape_html: true
end

# set session[:all_lists] as [] if doesn't exist
# set @all_lists to point at session[:all_lists]
before do
  session[:all_lists] = session[:all_lists] || []
  @all_lists = session[:all_lists]
end

# return numeral index for item, ex: "list2" returns 2
def numeral_index_for(item, leading_text)
  item.to_s.gsub(leading_text, '').to_i
end

# return the next sequential id
def next_element_id(items, leading_text)
  max_current_id = items.map { |item| numeral_index_for(item[:id], leading_text) }.max || -1
  leading_text + (max_current_id + 1).to_s
end

# find an item by its [:id]
def item_by_id(array, search_query)
  array.each do |item|
    return item if item[:id] == search_query
  end
  nil
end

# helper methods concerning list's and todo's status and counts
helpers do
  # classify <li> tag (completed vs not)
  def li_class_for(item)
    'complete' if item[:completed]
  end

  # return total totos count
  def total_todos_count(list)
    list[:todos].count
  end

  # return completed todos count
  def completed_todos_count(list)
    list[:todos].count { |todo| todo[:completed] }
  end
end

# helper methods to help with flash messages
helpers do
  # return if a message indicates success or error
  def message_class
    return 'success' if session[:success]
    return 'error' if session[:error]
  end

  # clear the message of a type
  def clear_message(type)
    session[type.to_sym] = nil
  end

  # return the message text (either success or error)
  def message_text
    text = message_class
    return session[text.to_sym] unless text.nil?
  end

  # if there is a flash message to display
  def message?
    !!message_text
  end
end

# helper method to help with list order for display purposes
helpers do
  # return a result array with non-completes before completes
  def sort_by_completion_status(list)
    completes, non_completes = list.partition { |item| item[:completed] }
    (non_completes + completes)
  end
end

# mark session sucessful
def mark_session_sucessful(message = nil)
  session[:success] = message
end

# mark session failed
def mark_session_failed(message = nil)
  session[:error] = message
end

# save error message to session[:error] if there is any
def check_list_name_for_error(name)
  if !(1..100).cover?(name.length)
    mark_session_failed('List name must be between 1 and 100 characaters')
  elsif session[:all_lists].any? { |list| list[:name] == name }
    mark_session_failed('List name must be unique')
  end
end

# save error message to session[:error] if there is any
def check_todo_name_for_error(name)
  mark_session_failed('Todo item must be between 1 and 100 characters') unless (1..100).cover?(name.length)
end

# mark an item as completed
def mark_item_completed(item)
  item[:completed] = true
end

# mark an item as incompleted
def mark_item_incompleted(item)
  item[:completed] = false
end

# return true for "true", false for "false"
def boolean(value)
  value == 'true'
end

# check if a list's all todos are completed
# return false if empty list
def all_todos_completed?(list)
  return false if list[:todos].empty?
  return false if list[:todos].any? { |todo| !todo[:completed] }

  true
end

# redirect back to /all-lists + page not found error
not_found do
  mark_session_failed('The page you requested does not exist')
  redirect '/all-lists'
end

# redirect back to /all-lists
get '/' do
  redirect '/all-lists'
end

# view all lists
get '/all-lists' do
  erb :all_lists
end

# render the form to add new list
get '/all-lists/new' do
  erb :new_list
end

# add a new list if name entered is valid
# re-render the form to add new list if name entered is invalid
post '/all-lists/new' do
  name = (params[:new_list_name] || '').strip
  check_list_name_for_error(name)
  if message?
    erb :new_list
  else
    @all_lists << { id: next_element_id(@all_lists, 'list'), name: name, completed: false, todos: [] }
    mark_session_sucessful('A new list has been added')
    redirect '/all-lists'
  end
end

# see a single list + list_id validation/ redirected to home if not found
get '/all-lists/:list_id' do
  @current_list = item_by_id(@all_lists, params[:list_id])
  if @current_list.nil?
    mark_session_failed('The list you requested does not exist')
    redirect '/all-lists'
  end
  erb :single_list
end

# add a todo item to the current list
post '/all-lists/:list_id' do
  @current_list = item_by_id(@all_lists, params[:list_id])
  todo_name = params[:new_todo_name].strip
  check_todo_name_for_error(todo_name)
  if message?
    erb :single_list
  else
    todo_id = next_element_id(@current_list[:todos], 'todo')
    @current_list[:todos] << { id: todo_id, name: todo_name, completed: false }
    mark_session_sucessful('A new todo item was added')
    redirect "/all-lists/#{params[:list_id]}"
  end
end

# check all todos as completed + mark list completed + then redirect to single list page
post '/all-lists/:list_id/complete-all' do
  @current_list = item_by_id(@all_lists, params[:list_id])
  @current_list[:todos].each { |todo| mark_item_completed(todo) }
  mark_item_completed(@current_list)
  redirect "/all-lists/#{params[:list_id]}"
end

# render the edit_list form + list_id validation/ redirected to home if not found
get '/all-lists/:list_id/edit' do
  @current_list = item_by_id(@all_lists, params[:list_id])
  if @current_list.nil?
    mark_session_failed('The list you requested does not exist')
    redirect '/all-lists'
  end
  erb :edit_list
end

# edit the list name if name is valid
post '/all-lists/:list_id/edit' do
  @current_list = item_by_id(@all_lists, params[:list_id])

  new_name = (params[:new_list_name] || '').strip
  old_name = @current_list[:name]
  @current_list[:name] = ''

  check_list_name_for_error(new_name)
  if message?
    @current_list[:name] = old_name
    erb :edit_list
  else
    @current_list[:name] = new_name
    mark_session_sucessful('The list name has been updated')
    redirect "/all-lists/#{@current_list[:id]}"
  end
end

# delete the list and redirect to front page
post '/all-lists/:list_id/delete' do
  list_to_delete = item_by_id(@all_lists, params[:list_id])
  @all_lists.delete(list_to_delete)

  mark_session_sucessful('A list was succesfully deleted')

  redirect '/all-lists'
end

# toggle a todo item in the list + check if that makes a list completed
post '/all-lists/:list_id/todos/:todo_id' do
  @current_list = item_by_id(@all_lists, params[:list_id])
  current_todo = item_by_id(@current_list[:todos], params[:todo_id])
  current_todo[:completed] = boolean(params[:completed])

  @current_list[:completed] = all_todos_completed?(@current_list)

  erb :single_list
end

# delete a todo item + check if that makes a list completed + redirect to single_list page
post '/all-lists/:list_id/todos/:todo_id/delete' do
  @current_list = item_by_id(@all_lists, params[:list_id])
  todo_to_delete = item_by_id(@current_list[:todos], params[:todo_id])

  @current_list[:todos].delete(todo_to_delete)
  mark_session_sucessful('A todo item was succesfully deleted')

  @current_list[:completed] = all_todos_completed?(@current_list)

  redirect "/all-lists/#{params[:list_id]}"
end
