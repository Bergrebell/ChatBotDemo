require 'api-ai-ruby'

class TelegramWebhooksController < Telegram::Bot::UpdatesController
  include Telegram::Bot::UpdatesController::MessageContext
  context_to_action!

    CLIENT = ApiAiRuby::Client.new(
        :client_access_token => 'a0c1897506d44a75883663521e4b4c85'
    )

  def start(*)
    welcome_text = "Willkommen"
    respond_with :message, text: welcome_text
  end

  def help(*)
    respond_with :message, text: t('.content')
  end

  def memo(*args)
    if args.any?
      session[:memo] = args.join(' ')
      respond_with :message, text: t('.notice')
    else
      respond_with :message, text: t('.prompt')
      save_context :memo
    end
  end

  def remind_me
    to_remind = session.delete(:memo)
    reply = to_remind || t('.nothing')
    respond_with :message, text: reply
  end

  def keyboard(value = nil, *)
    if value
      respond_with :message, text: t('.selected', value: value)
    else
      save_context :keyboard
      respond_with :message, text: t('.prompt'), reply_markup: {
        keyboard: [t('.buttons')],
        resize_keyboard: true,
        one_time_keyboard: true,
        selective: true,
      }
    end
  end

  def inline_keyboard
    respond_with :message, text: t('.prompt'), reply_markup: {
      inline_keyboard: [
        [
          {text: t('.alert'), callback_data: 'alert'},
          {text: t('.no_alert'), callback_data: 'no_alert'},
          {text: "\u{1F60A}", callback_data: 'positive'},
          {text: "\u{1F610}", callback_data: 'neutral'},
          {text: "\u{1F61E}", callback_data: 'negative'},
        ],
        [{text: t('.repo'), url: 'https://github.com/telegram-bot-rb/telegram-bot'}],
      ],
    }
  end

  def message(message)
    return send_image_received_event if message['photo'].present?

    response = CLIENT.text_request(message['text'])
    puts "RESPONSE: #{ap response}"

    respond_with :message, text: response[:result][:fulfillment][:speech]
    do_action(response)
  end

  def send_image_received_event
    response = CLIENT.event_request 'IMAGE_RECEIVED'
    respond_with :message, text: response[:result][:fulfillment][:speech]
    do_action(response)
  end

  def do_action(response)
    action = response[:result][:action]
    return unless action
    case action
      when 'send_door_image'
        respond_with :photo, photo: File.open(Rails.root.join('app/assets/images/door.png'))
      when 'send_door_multiple_choice'
        send_door_multiple_choice
      when 'send_feedback_multiple_choice'
        send_feedback_multiple_choice
    end
  end

  def send_feedback_multiple_choice
    respond_with :message, text: 'Bitte wähle aus:', reply_markup: {
      inline_keyboard: [
        [
          {text: "\u{1F60A}", callback_data: 'positive'},
          {text: "\u{1F610}", callback_data: 'neutral'},
          {text: "\u{1F61E}", callback_data: 'negative'},
        ]
      ],
    }
  end

  def send_door_multiple_choice
    respond_with :message, text: 'Bitte wähle aus:', reply_markup: {
      inline_keyboard: [
        [
          {text: 'Klinke', callback_data: 'klinke'},
          {text: 'Schloss', callback_data: 'schloss'},
          {text: 'Rahmen', callback_data: 'rahmen'},
          {text: 'Andere', callback_data: 'andere'}
        ]
      ],
    }
  end

  def callback_query(data)
    message = {'text' => data}
    message(message)
  end

  def inline_query(query, offset)
    query = query.first(10) # it's just an example, don't use large queries.
    t_description = t('.description')
    t_content = t('.content')
    results = 5.times.map do |i|
      {
        type: :article,
        title: "#{query}-#{i}",
        id: "#{query}-#{i}",
        description: "#{t_description} #{i}",
        input_message_content: {
          message_text: "#{t_content} #{i}",
        },
      }
    end
    answer_inline_query results
  end

  # As there is no chat id in such requests, we can not respond instantly.
  # So we just save the result_id, and it's available then with `/last_chosen_inline_result`.
  def chosen_inline_result(result_id, query)
    session[:last_chosen_inline_result] = result_id
  end

  def last_chosen_inline_result
    result_id = session[:last_chosen_inline_result]
    if result_id
      respond_with :message, text: t('.selected', result_id: result_id)
    else
      respond_with :message, text: t('.prompt')
    end
  end

  def action_missing(action, *_args)
    if command?
      respond_with :message, text: t('telegram_webhooks.action_missing.command', command: action)
    else
      respond_with :message, text: t('telegram_webhooks.action_missing.feature', action: action)
    end
  end

end
