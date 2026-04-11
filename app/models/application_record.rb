class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  def self.execute_void_query(sql, name = "SQL", binds = [], prepare: false)
    connection.send(:internal_execute, sql, name, binds, prepare: prepare)
  end
end
