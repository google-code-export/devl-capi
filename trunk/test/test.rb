# p :object == ( :object || :container || :dataobject || :queue || :domain )

p [:object, :container, :dataobject, :queue, :domain].include?(:object)