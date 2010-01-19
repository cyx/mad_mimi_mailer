This is a fork of the mad_mimi_mailer gem which can be found [here](http://github.com/redsquirrel/mad_mimi_mailer).


What's the difference?
======================

This fork was made to address the following needs:

1. Invisibility
2. Unobtrusiveness
3. <Insert some dire need here>
  
Invisibility
------------

The original:

    class Notifiers::Activation < MadMimiMailer
      def mimi_instructions
        # usual mailer settings goes here
      end
    end
    
When you execute `Notifiers::Activation.deliver_mimi_instructions`, this sends to the recipient the promotion named `instructions`

My fork:

    class Notifiers::Activation < MadMimiMailer
      def instructions
        # usual mailer settings goes here
      end
    end
    
With the forked version, when you execute `Notifiers::Activation.deliver_instructions`, this sends to the recipient the promotion named __`activation_instructions`__.

You can change the settings somewhere in an initializer maybe:

    MadMimiMailer.defaults = { :use_erb => true }
    
just in case you want to force sending using `raw_html`. Note that as of the moment (2010/01/19), this results in a 500 Internal Server Error. So it's best to stay with the defaults, and just create a promotion for each of your existing mailer templates.

Todos / Roadmap
---------------

1. Maybe it's best to just inherit from ActionMailer::Base and specify `ActionMailer::Base.delivery_method = :mad_mimi`. As of now, what we have works though.
2. Try and figure out why `use_erb` fails.
3. Determine the use of hidden in conjunction with this fork.
    
    
