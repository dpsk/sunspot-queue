require "spec_helper"

describe Sunspot::Queue::SessionProxy do
  let(:proxy) { Sunspot::Queue::SessionProxy.new(mock) }

  context "#index" do
    it "enqueues a single job for each class" do
      people = 5.times.map do |i|
        Person.create(:name => "#{i} of 5")
      end

      Resque.should_receive(:enqueue).with do |job, klass, id|
        job.should == ::Sunspot::Queue::IndexJob
        klass.should == "Person"
      end.exactly(5).times

      proxy.index(people)
    end

    it "handles an array of objects given to index" do
      people = 2.times.map do |i|
        Person.create(:name => "Clone ##{i}")
      end

      Resque.should_receive(:enqueue).exactly(2).times

      proxy.index(people)
    end

    it "handles a single object being enqueued" do
      person = Person.create(:name => "Buttercup")

      Resque.should_receive(:enqueue).with do |_,_,id|
        id.should == person.id
      end

      proxy.index(person)
    end

    it "raises an error if object is not persisted" do
      person = Person.new(:name => "Vizzini")

      expect do
        proxy.index(person)
      end.to raise_error(Sunspot::Queue::NotPersistedError)
    end

    it "raises an error if one of a set is not persisted" do
      people = 5.times.map do |i|
        Person.new(:name => "Minion ##{i}")
      end

      # This will leave 1 person not saved to the database
      4.times { |i| people[i].save }

      expect do
        proxy.index(people)
      end.to raise_error(Sunspot::Queue::NotPersistedError)
    end

    it "does not process any records if one is not persisted" do
      people = 2.times.map { |i| Person.new(:name => i) }
      people.first.save

      Resque.should_not_receive(:enqueue)
      expect do
        proxy.index(people)
      end.to raise_error(Sunspot::Queue::NotPersistedError)
    end
  end

  context "#remove" do
    it "enqueues a single job for each class" do
      people = 5.times.map do |i|
        Person.create(:name => "#{i} of 5")
      end

      Resque.should_receive(:enqueue).with do |job, klass, id|
        job.should == ::Sunspot::Queue::RemovalJob
        klass.should == "Person"
      end.exactly(5).times

      proxy.remove(people)
    end

    it "handles an array of objects" do
      people = 2.times.map do |i|
        Person.create(:name => "Clone ##{i}")
      end

      Resque.should_receive(:enqueue).exactly(2).times

      proxy.remove(people)
    end

    it "handles a single object" do
      person = Person.create(:name => "Buttercup")

      Resque.should_receive(:enqueue).with do |job, _, id|
        job.should == ::Sunspot::Queue::RemovalJob
        id.should == person.id
      end

      proxy.remove(person)
    end

    it "silently ignores records that do not have an id" do
      people = 2.times.map { |i| Person.new(:name => "Thing #{i}") }
      people.first.save

      Resque.should_receive(:enqueue).once

      proxy.remove(people)
    end
  end
end
