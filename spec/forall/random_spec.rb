describe Forall::Random do
  before do
    @rnd = Forall::Random.new(seed: 123456789)
  end

  describe "#boolean" do
    it "returns true or false" do
      forall(sampled{|_| }).check{|_| [true, false].include?(@rnd.boolean) }
    end

    it "uses the given random seed" do
      expect(@rnd.boolean).to eq(true)
      expect(@rnd.boolean).to eq(true)
      expect(@rnd.boolean).to eq(true)
      expect(@rnd.boolean).to eq(true)
      expect(@rnd.boolean).to eq(false)
      expect(@rnd.boolean).to eq(true)
      expect(@rnd.boolean).to eq(true)
      expect(@rnd.boolean).to eq(false)
    end
  end

  describe "#integer" do
    it "has no required arguments" do
      forall(sampled{|_| }).check{|_| expect(@rnd.integer).to be_a(Integer) }
    end

    it "returns a value within given range" do
      forall(sampled{|rnd| rnd.range(-100..100)}).check do |range|
        @rnd.integer(range).then do |x|
          expect(x).to     be_a(Integer)
          expect(range).to include(x)
        end
      end
    end

    it "it uses the given random seed" do
      expect(@rnd.integer(10..99)).to eq(66)
      expect(@rnd.integer(10..99)).to eq(38)
      expect(@rnd.integer(10..99)).to eq(60)
      expect(@rnd.integer(10..99)).to eq(99)
      expect(@rnd.integer(10..99)).to eq(39)
      expect(@rnd.integer(10..99)).to eq(17)
      expect(@rnd.integer(10..99)).to eq(89)
      expect(@rnd.integer(10..99)).to eq(93)
    end
  end

  describe "#float" do
    it "has no required arguments" do
      forall(sampled{|_| }).check{|_| @rnd.float.is_a?(Float) }
    end

    it "returns a value within the given range" do
      forall(sampled{|rnd| rnd.range(-100.0..100.0)}).check do |range|
        @rnd.float(range).then do |x|
          expect(x).to     be_a(Float)
          expect(range).to include(x)
        end
      end
    end

    it "uses the given random seed" do
      expect(@rnd.float(10.0..99.9)).to eq(57.901688788146565)
      expect(@rnd.float(10.0..99.9)).to eq(58.018880788279375)
      expect(@rnd.float(10.0..99.9)).to eq(55.80881796834886 )
      expect(@rnd.float(10.0..99.9)).to eq(74.14940662527147 )
      expect(@rnd.float(10.0..99.9)).to eq(33.10420605397002 )
      expect(@rnd.float(10.0..99.9)).to eq(77.66715571073766 )
      expect(@rnd.float(10.0..99.9)).to eq(89.46073832691911 )
      expect(@rnd.float(10.0..99.9)).to eq(23.925427336927644)
    end
  end

  describe "#date" do
    before do
      require "date"
      @a = Date.civil(1000,1,1)
      @b = Date.civil(3000,12,31)
    end

    it "has no required arguments" do
      forall(sampled{|_| }).check{|_| @rnd.date.is_a?(Date) }
    end

    it "returns a value within the given range" do
      forall(sampled{|rnd| rnd.range(@a..@b) }).check do |range|
        @rnd.date(range).then do |x|
          expect(x).to be_a(Date)
          expect(x).to be_between(range.min, range.max)
        end
      end
    end

    it "uses the given random seed" do
      expect(@rnd.date(@a..@b)).to eq(Date.civil(2066,  3, 16))
      expect(@rnd.date(@a..@b)).to eq(Date.civil(2068, 10, 24))
      expect(@rnd.date(@a..@b)).to eq(Date.civil(2019,  8, 16))
      expect(@rnd.date(@a..@b)).to eq(Date.civil(2427, 11, 05))
      expect(@rnd.date(@a..@b)).to eq(Date.civil(1514,  3, 29))
      expect(@rnd.date(@a..@b)).to eq(Date.civil(2506,  2, 22))
      expect(@rnd.date(@a..@b)).to eq(Date.civil(2768,  8, 23))
      expect(@rnd.date(@a..@b)).to eq(Date.civil(1309, 12, 11))
    end
  end

  describe "#time" do
    before do
      @a = Time.at(-10000000000)
      @b = Time.at( 99999999999)
    end

    it "has no required arguments" do
      forall(sampled{|_| }).check{|_| @rnd.time.is_a?(Time) }
    end

    it "returns a value wwithin the given range" do
      forall(sampled{|rnd| rnd.range(@a..@b) }).check do |range|
        @rnd.time(range).then do |x|
          expect(x).to be_a(Time)
          expect(x).to be_between(range.min, range.max)
        end
      end
    end

    it "uses the given random seed" do
      expect(@rnd.time(@a..@b)).to eq(Time.at(48611632554.48521))
      expect(@rnd.time(@a..@b)).to eq(Time.at(48755026547.97232))
      expect(@rnd.time(@a..@b)).to eq(Time.at(46050833998.58249))
      expect(@rnd.time(@a..@b)).to eq(Time.at(68492043700.953415))
      expect(@rnd.time(@a..@b)).to eq(Time.at(18269885049.094524))
      expect(@rnd.time(@a..@b)).to eq(Time.at(72796297309.38237))
      expect(@rnd.time(@a..@b)).to eq(Time.at(87226709854.07832))
      expect(@rnd.time(@a..@b)).to eq(Time.at(7038898854.817745))
    end
  end

  todo "#datetime"

  describe "#range" do
    context "of integers" do
      before do
        @a = -100
        @b =  100
      end

      it "returns a range within the given range" do
        forall(sampled{|rnd| rnd.range(@a..@b)}).check do |range|
          expect(@a..@b).to be_cover(range)

          @rnd.range(range).then do |x|
            expect(x).to     be_a(Range)
            expect(x.min).to be_a(Integer)
            expect(x.max).to be_a(Integer)
            expect(range).to be_cover(x)
          end
        end
      end

      it "uses the given random seed" do
        expect(@rnd.range(@a..@b)).to eq(56..84  )
        expect(@rnd.range(@a..@b)).to eq(-50..-10)
        expect(@rnd.range(@a..@b)).to eq(-93..-71)
        expect(@rnd.range(@a..@b)).to eq(-21..88 )
        expect(@rnd.range(@a..@b)).to eq(-16..-1 )
        expect(@rnd.range(@a..@b)).to eq(11..16  )
        expect(@rnd.range(@a..@b)).to eq(-18..23 )
        expect(@rnd.range(@a..@b)).to eq(7..8    )
      end
    end

    context "of floats" do
      before do
        @a = -100.0
        @b =  100.0
      end

      it "returns a range within the given range" do
        forall(sampled{|rnd| rnd.range(@a..@b)}).check do |range|
          expect(@a..@b).to be_cover(range)

          @rnd.range(range).then do |x|
            expect(x).to     be_a(Range)
            expect(x.min).to be_a(Float)
            expect(x.max).to be_a(Float)
            expect(range).to be_cover(x)
          end
        end
      end

      it "uses the given random seed" do
        expect(@rnd.range(@a..@b)).to eq(6.566604645487345..6.827320997284474  )
        expect(@rnd.range(@a..@b)).to eq(1.9106072710764295..42.71280673030361 )
        expect(@rnd.range(@a..@b)).to eq(-48.60020900117905..50.53872238206375 )
        expect(@rnd.range(@a..@b)).to eq(-69.02018390004974..76.77583609993127 )
        expect(@rnd.range(@a..@b)).to eq(28.68903224722169..34.109287125695744 )
        expect(@rnd.range(@a..@b)).to eq(44.725433856529065..49.745040910752124)
        expect(@rnd.range(@a..@b)).to eq(-80.41829562321206..63.70947866752053 )
        expect(@rnd.range(@a..@b)).to eq(-99.28921818030085..-53.83807606108226)
      end
    end

    context "of characters" do
      before do
        @a = "a"
        @b = "z"
      end
      it "returns a range within the given range" do
        forall(sampled{|rnd| rnd.range(@a..@b)}).check do |range|
          expect(@a..@b).to be_cover(range)

          @rnd.range(range).then do |x|
            expect(x).to     be_a(Range)
            expect(x.min).to be_a(String)
            expect(x.max).to be_a(String)
            expect(range).to be_cover(x)
          end
        end
      end

      it "uses the given random seed" do
        expect(@rnd.range(@a..@b)).to eq("s".."y")
        expect(@rnd.range(@a..@b)).to eq("m".."z")
        expect(@rnd.range(@a..@b)).to eq("e".."h")
        expect(@rnd.range(@a..@b)).to eq("p".."t")
        expect(@rnd.range(@a..@b)).to eq("n".."u")
        expect(@rnd.range(@a..@b)).to eq("a".."d")
        expect(@rnd.range(@a..@b)).to eq("p".."u")
        expect(@rnd.range(@a..@b)).to eq("o".."s")
      end
    end

    context "of dates" do
      before do
        @a = Date.civil(1200, 1, 1)
        @b = Date.civil(2500, 1, 1)
      end

      it "returns a range within the given range" do
        forall(sampled{|rnd| rnd.range(@a..@b)}).check do |range|
          expect(@a..@b).to be_cover(range)

          @rnd.range(range).then do |x|
            expect(x).to     be_a(Range)
            expect(x.min).to be_a(Date)
            expect(x.max).to be_a(Date)
            expect(range).to be_cover(x)
          end
        end
      end

      it "uses the given random seed" do
        expect(@rnd.range(@a..@b)).to eq(Date.civil(1892, 9,10)..Date.civil(1894, 5,22))
        expect(@rnd.range(@a..@b)).to eq(Date.civil(1862, 6, 6)..Date.civil(2127, 8,23))
        expect(@rnd.range(@a..@b)).to eq(Date.civil(1534, 2, 1)..Date.civil(2178, 7, 5))
        expect(@rnd.range(@a..@b)).to eq(Date.civil(1401, 5,12)..Date.civil(2349, 1,18))
        expect(@rnd.range(@a..@b)).to eq(Date.civil(2036, 6,27)..Date.civil(2071, 9,20))
        expect(@rnd.range(@a..@b)).to eq(Date.civil(2140, 9,21)..Date.civil(2173, 5, 8))
        expect(@rnd.range(@a..@b)).to eq(Date.civil(1327, 4,11)..Date.civil(2264, 2,13))
        expect(@rnd.range(@a..@b)).to eq(Date.civil(1204, 8,14)..Date.civil(1500, 1,16))
      end
    end

    context "of times" do
      before do
        @a = Time.at(-10000000000)
        @b = Time.at( 99999999999)
      end

      it "returns a range within the given range" do
        forall(sampled{|rnd| rnd.range(@a..@b)}).check do |range|
          expect(@a..@b).to be_cover(range)

          @rnd.range(range).then do |x|
            expect(x).to     be_a(Range)
            expect(x.min).to be_a(Time)
            expect(x.max).to be_a(Time)
            expect(range).to be_cover(x)
          end
        end
      end

      it "uses the given random seed" do
        expect(@rnd.range(@a..@b)).to eq(Time.at( 48611632554.48521 )..Time.at(48755026547.97232))
        expect(@rnd.range(@a..@b)).to eq(Time.at( 46050833998.58249 )..Time.at(68492043700.953415))
        expect(@rnd.range(@a..@b)).to eq(Time.at( 18269885049.094524)..Time.at(72796297309.38237))
        expect(@rnd.range(@a..@b)).to eq(Time.at( 7038898854.817745 )..Time.at(87226709854.07832))
        expect(@rnd.range(@a..@b)).to eq(Time.at( 60778967735.328476)..Time.at(63760107918.46211))
        expect(@rnd.range(@a..@b)).to eq(Time.at( 69598988620.36737 )..Time.at(72359772500.16493))
        expect(@rnd.range(@a..@b)).to eq(Time.at( 769937407.1354618 )..Time.at(80040213266.31773))
        expect(@rnd.range(@a..@b)).to eq(Time.at(-9609069999.169024 )..Time.at(15389058166.173946))
      end
    end

    todo "of datetimes"
  end

  describe "#sample" do
    context "without a count: argument" do
      context "on sampled{...}" do
        before do
          @input = sampled{|rnd| rnd.integer(-1000..1000) }
        end

        it "returns a value from the distribution" do
          forall(sampled{|_| }).check{|_| expect(@rnd.sample(@input)).to be_between(-1000, 1000) }
        end

        it "uses the given random seed" do
          expect(@rnd.sample(@input)).to eq(720 )
          expect(@rnd.sample(@input)).to eq(692 )
          expect(@rnd.sample(@input)).to eq(330 )
          expect(@rnd.sample(@input)).to eq(-654)
          expect(@rnd.sample(@input)).to eq(-203)
          expect(@rnd.sample(@input)).to eq(-508)
          expect(@rnd.sample(@input)).to eq(-225)
          expect(@rnd.sample(@input)).to eq(786 )
        end
      end

      context "on an array" do
        before do
          @input = %w(a b c d e f)
        end

        it "returns a value from the distribution" do
          forall(sampled{|_| }).check{|_| expect(@input).to include(@rnd.sample(@input)) }
        end

        it "uses the given random seed" do
          expect(@rnd.sample(@input)).to eq("a")
          expect(@rnd.sample(@input)).to eq("e")
          expect(@rnd.sample(@input)).to eq("c")
          expect(@rnd.sample(@input)).to eq("b")
          expect(@rnd.sample(@input)).to eq("c")
          expect(@rnd.sample(@input)).to eq("f")
          expect(@rnd.sample(@input)).to eq("e")
          expect(@rnd.sample(@input)).to eq("c")
        end
      end

      context "on a range" do
        before do
          @input = 500..599
        end

        it "returns a value from the distribution" do
          forall(sampled{|_| }).check{|_| expect(@input).to include(@rnd.sample(@input)) }
        end

        it "uses the given random seed" do
          expect(@rnd.sample(@input)).to eq(556)
          expect(@rnd.sample(@input)).to eq(528)
          expect(@rnd.sample(@input)).to eq(550)
          expect(@rnd.sample(@input)).to eq(589)
          expect(@rnd.sample(@input)).to eq(590)
          expect(@rnd.sample(@input)).to eq(529)
          expect(@rnd.sample(@input)).to eq(507)
          expect(@rnd.sample(@input)).to eq(579)
        end
      end

      todo "on a non-enumerable value"
    end

    context "with a count: argument" do
      todo "on sampled{...}"

      todo "on a range"

      todo "on an array"

      todo "on a non-enumerable value"
    end
  end

  describe "#shuffle" do
    it "returns a permutation" do
      forall(sampled{|rnd| rnd.array{|_| rnd.integer }}).check do |array|
        expect(@rnd.shuffle(array).sort).to eq(array.sort)
      end
    end

    todo "uses the given random seed"
  end

  describe "#array" do
    todo "with unspecified size"

    todo "with fixed size"

    todo "with size range"
  end

  describe "#hash" do
    todo "with unspecified size"

    todo "with fixed size"

    todo "with size range"
  end

  describe "#set" do
    todo "with unspecified size"

    todo "with fixed size"

    todo "with size range"
  end
end
