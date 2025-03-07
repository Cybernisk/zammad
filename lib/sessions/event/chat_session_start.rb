class Sessions::Event::ChatSessionStart < Sessions::Event::ChatBase

=begin

a agent start`s a new chat session

payload

  {
    event: 'chat_session_start',
    data: {},
  }

return is sent as message back to peer

=end

  def run
    return super if super
    return if !permission_check('chat.agent', 'chat')

    # find first in waiting list
    chat_user = User.lookup(id: @session['id'])
    chat_ids = Chat.agent_active_chat_ids(chat_user)
    chat_session = Chat::Session.where(state: 'waiting', chat_id: chat_ids).order(created_at: :asc).first
    if !chat_session
      return {
        event: 'chat_session_start',
        data:  {
          state:   'failed',
          message: 'No session available.',
        },
      }
    end
    chat_session.user_id = chat_user.id
    chat_session.state = 'running'
    chat_session.preferences[:participants] = chat_session.add_recipient(@client_id)
    chat_session.save

    # send chat_session_init to client
    user = chat_session.agent_user
    data = {
      event: 'chat_session_start',
      data:  {
        state:      'ok',
        agent:      user,
        session_id: chat_session.session_id,
        chat_id:    chat_session.chat_id,
      },
    }
    # send to customer
    chat_session.send_to_recipients(data, @client_id)

    # send to agent
    data = {
      event: 'chat_session_start',
      data:  {
        session: chat_session.attributes,
      },
    }
    Sessions.send(@client_id, data)

    # send state update with sessions to agents
    Chat.broadcast_agent_state_update([chat_session.chat_id])

    # send position update to other waiting sessions
    Chat.broadcast_customer_state_update(chat_session.chat_id)

    nil
  end

end
